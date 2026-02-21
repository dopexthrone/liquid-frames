import Foundation

enum AgentCommandLine {
    static func runIfRequested(
        arguments: [String] = CommandLine.arguments,
        emitOutput: Bool = true
    ) -> Int32? {
        guard let markerIndex = arguments.firstIndex(of: "--agent") else {
            return nil
        }

        let tail = Array(arguments.dropFirst(markerIndex + 1))
        do {
            let command = try parseCommand(tail)
            let result = try execute(command: command)
            if emitOutput {
                writeStdout(result.output)
            }
            return result.exitCode
        } catch {
            if emitOutput {
                let message = "liquid-frames agent error: \(error.localizedDescription)\n\n\(helpText)\n"
                writeStderr(message)
            }
            return ExitCode.usage.rawValue
        }
    }

    private static func parseCommand(_ args: [String]) throws -> Command {
        guard let verb = args.first else {
            throw CLIError("missing command after --agent")
        }

        let flags = Array(args.dropFirst())
        switch verb {
        case "check":
            return .check(try parseCheckOptions(flags: flags))
        case "benchmark":
            return .benchmark(try parseBenchmarkOptions(flags: flags))
        case "help", "--help", "-h":
            return .help
        default:
            throw CLIError("unknown agent command '\(verb)'")
        }
    }

    private static func parseCheckOptions(flags: [String]) throws -> AgentCheckOptions {
        var options = AgentCheckOptions()
        var index = 0

        while index < flags.count {
            let token = flags[index]
            switch token {
            case "--workspace":
                options.workspacePath = try requireValue(after: token, at: index, in: flags)
                index += 2
            case "--min-runs":
                let raw = try requireValue(after: token, at: index, in: flags)
                guard let value = Int(raw), value >= 0 else {
                    throw CLIError("--min-runs must be a non-negative integer")
                }
                options.minRuns = value
                index += 2
            case "--require-grade":
                let raw = try requireValue(after: token, at: index, in: flags)
                guard let grade = parseGrade(raw) else {
                    throw CLIError("--require-grade must be one of: A, B, C, D")
                }
                options.requireGrade = grade
                index += 2
            case "--require-quality":
                let raw = try requireValue(after: token, at: index, in: flags)
                guard let level = MotionQualityLevel(rawValue: raw.lowercased()) else {
                    throw CLIError("--require-quality must be one of: healthy, caution, unstable")
                }
                options.requireQuality = level
                index += 2
            case "--allow-attention":
                options.allowAttention = true
                index += 1
            case "--pretty":
                options.pretty = true
                index += 1
            case "--export-markdown":
                options.exportMarkdownPath = try requireValue(after: token, at: index, in: flags)
                index += 2
            default:
                throw CLIError("unknown check flag '\(token)'")
            }
        }

        return options
    }

    private static func parseBenchmarkOptions(flags: [String]) throws -> AgentBenchmarkOptions {
        var options = AgentBenchmarkOptions()
        var index = 0

        while index < flags.count {
            let token = flags[index]
            switch token {
            case "--preset":
                let raw = try requireValue(after: token, at: index, in: flags)
                guard let preset = MotionPreset(rawValue: raw.lowercased()) else {
                    throw CLIError("--preset must be one of: balanced, responsive, cinematic")
                }
                options.preset = preset
                index += 2
            case "--pretty":
                options.pretty = true
                index += 1
            default:
                throw CLIError("unknown benchmark flag '\(token)'")
            }
        }

        return options
    }

    private static func requireValue(after flag: String, at index: Int, in args: [String]) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < args.count else {
            throw CLIError("missing value for \(flag)")
        }
        return args[valueIndex]
    }

    private static func parseGrade(_ value: String) -> MotionBenchmarkGrade? {
        MotionBenchmarkGrade(rawValue: value.uppercased())
    }

    private static func execute(command: Command) throws -> ExecutionResult {
        switch command {
        case .help:
            return ExecutionResult(output: helpText + "\n", exitCode: ExitCode.success.rawValue)
        case .benchmark(let options):
            let report = MotionBenchmarkEngine.runSuite(tuning: options.preset.tuning)
            let payload = AgentBenchmarkPayload(
                schemaVersion: 1,
                generatedAt: isoString(Date()),
                preset: options.preset.rawValue,
                grade: report.grade.rawValue,
                overallScore: report.overallScore,
                consistencyScore: report.consistencyScore,
                qualityLevel: report.quality.level.rawValue,
                scenarios: report.scenarios.map { scenario in
                    AgentScenarioPayload(
                        name: scenario.scenarioName,
                        trigger: scenario.trigger.rawValue,
                        estimatedDuration: scenario.estimatedDuration,
                        score: scenario.score
                    )
                }
            )
            let output = try jsonString(payload, pretty: options.pretty)
            return ExecutionResult(output: output + "\n", exitCode: ExitCode.success.rawValue)
        case .check(let options):
            let result = try runCheck(options: options)
            let output = try jsonString(result.payload, pretty: options.pretty)
            return ExecutionResult(output: output + "\n", exitCode: result.exitCode)
        }
    }

    private static func runCheck(options: AgentCheckOptions) throws -> CheckExecutionResult {
        let workspaceURL = options.workspacePath.map { URL(fileURLWithPath: $0) } ?? MotionStorage.defaultWorkspaceURL()

        do {
            let snapshot = try MotionStorage.load(from: workspaceURL)
            let profiles = snapshot.profiles.map(\.profile).map { $0.withNormalizedMetadata() }
            guard let activeProfile = resolveActiveProfile(in: profiles, activeID: snapshot.activeProfileID) else {
                let payload = AgentCheckPayload(
                    schemaVersion: 1,
                    generatedAt: isoString(Date()),
                    workspacePath: workspaceURL.path,
                    activeProfile: nil,
                    releaseGateStatus: MotionReleaseGateStatus.blocked.rawValue,
                    qualityLevel: MotionQualityLevel.unstable.rawValue,
                    benchmarkGrade: nil,
                    runCount: snapshot.runHistory.count,
                    benchmarkHistoryCount: snapshot.benchmarkHistory.count,
                    passed: false,
                    policyFailures: ["No profiles were found in workspace snapshot."],
                    gateFindings: ["No active profile is available."],
                    benchmarkOverallScore: nil,
                    benchmarkConsistencyScore: nil,
                    regressionStatus: nil,
                    thresholds: ThresholdPayload(
                        minRuns: options.minRuns,
                        requireGrade: options.requireGrade.rawValue,
                        requireQuality: options.requireQuality.rawValue,
                        allowAttention: options.allowAttention
                    )
                )
                return CheckExecutionResult(payload: payload, exitCode: ExitCode.failedGate.rawValue)
            }

            let runHistory = snapshot.runHistory.map(\.metrics).sorted(by: { $0.timestamp > $1.timestamp })
            let quality = MotionQualityEvaluator.evaluate(tuning: activeProfile.tuning, recentRuns: runHistory)
            let benchmark = snapshot.latestBenchmark?.report ?? MotionBenchmarkEngine.runSuite(tuning: activeProfile.tuning)
            let regression = activeProfile.baseline.map { baseline in
                MotionBenchmarkRegressionEvaluator.compare(report: benchmark, baseline: baseline)
            }

            let gate = MotionReleaseGateReport(
                generatedAt: Date(),
                workspacePath: workspaceURL.path,
                profile: activeProfile,
                profileIsDirty: false,
                quality: quality,
                benchmark: benchmark,
                regression: regression,
                latestRun: runHistory.first,
                runCount: runHistory.count,
                benchmarkHistoryCount: snapshot.benchmarkHistory.count
            )

            if let exportPath = options.exportMarkdownPath {
                let exportURL = URL(fileURLWithPath: exportPath)
                _ = try MotionStorage.save(text: gate.markdown, to: exportURL)
            }

            let failures = evaluatePolicyFailures(
                gate: gate,
                benchmark: benchmark,
                quality: quality,
                runCount: runHistory.count,
                options: options
            )
            let passed = failures.isEmpty
            let payload = AgentCheckPayload(
                schemaVersion: 1,
                generatedAt: isoString(Date()),
                workspacePath: workspaceURL.path,
                activeProfile: activeProfile.name,
                releaseGateStatus: gate.status.rawValue,
                qualityLevel: quality.level.rawValue,
                benchmarkGrade: benchmark.grade.rawValue,
                runCount: runHistory.count,
                benchmarkHistoryCount: snapshot.benchmarkHistory.count,
                passed: passed,
                policyFailures: failures,
                gateFindings: gate.findings,
                benchmarkOverallScore: benchmark.overallScore,
                benchmarkConsistencyScore: benchmark.consistencyScore,
                regressionStatus: regression?.status.rawValue,
                thresholds: ThresholdPayload(
                    minRuns: options.minRuns,
                    requireGrade: options.requireGrade.rawValue,
                    requireQuality: options.requireQuality.rawValue,
                    allowAttention: options.allowAttention
                )
            )

            return CheckExecutionResult(
                payload: payload,
                exitCode: passed ? ExitCode.success.rawValue : ExitCode.failedGate.rawValue
            )
        } catch MotionStorageError.snapshotNotFound {
            let payload = AgentCheckPayload(
                schemaVersion: 1,
                generatedAt: isoString(Date()),
                workspacePath: workspaceURL.path,
                activeProfile: nil,
                releaseGateStatus: MotionReleaseGateStatus.blocked.rawValue,
                qualityLevel: MotionQualityLevel.unstable.rawValue,
                benchmarkGrade: nil,
                runCount: 0,
                benchmarkHistoryCount: 0,
                passed: false,
                policyFailures: ["Workspace snapshot not found."],
                gateFindings: ["Expected snapshot at \(workspaceURL.path)."],
                benchmarkOverallScore: nil,
                benchmarkConsistencyScore: nil,
                regressionStatus: nil,
                thresholds: ThresholdPayload(
                    minRuns: options.minRuns,
                    requireGrade: options.requireGrade.rawValue,
                    requireQuality: options.requireQuality.rawValue,
                    allowAttention: options.allowAttention
                )
            )
            return CheckExecutionResult(payload: payload, exitCode: ExitCode.failedGate.rawValue)
        }
    }

    private static func resolveActiveProfile(in profiles: [MotionProfile], activeID: String?) -> MotionProfile? {
        let activeUUID = activeID.flatMap(UUID.init(uuidString:))
        if let activeUUID {
            return profiles.first(where: { $0.id == activeUUID }) ?? profiles.first
        }
        return profiles.first
    }

    private static func evaluatePolicyFailures(
        gate: MotionReleaseGateReport,
        benchmark: MotionBenchmarkReport,
        quality: MotionQualityReport,
        runCount: Int,
        options: AgentCheckOptions
    ) -> [String] {
        var failures: [String] = []

        if !gateStatusPasses(gate.status, allowAttention: options.allowAttention) {
            failures.append("Release gate status \(gate.status.rawValue) is below required status.")
        }

        if !gradePasses(actual: benchmark.grade, required: options.requireGrade) {
            failures.append("Benchmark grade \(benchmark.grade.rawValue) is below required \(options.requireGrade.rawValue).")
        }

        if !qualityPasses(actual: quality.level, required: options.requireQuality) {
            failures.append("Quality level \(quality.level.rawValue) is below required \(options.requireQuality.rawValue).")
        }

        if runCount < options.minRuns {
            failures.append("Run count \(runCount) is below required minimum \(options.minRuns).")
        }

        return failures
    }

    private static func gradePasses(actual: MotionBenchmarkGrade, required: MotionBenchmarkGrade) -> Bool {
        gradeRank(actual) >= gradeRank(required)
    }

    private static func gradeRank(_ grade: MotionBenchmarkGrade) -> Int {
        switch grade {
        case .a:
            return 4
        case .b:
            return 3
        case .c:
            return 2
        case .d:
            return 1
        }
    }

    private static func qualityPasses(actual: MotionQualityLevel, required: MotionQualityLevel) -> Bool {
        qualityRank(actual) <= qualityRank(required)
    }

    private static func qualityRank(_ level: MotionQualityLevel) -> Int {
        switch level {
        case .healthy:
            return 0
        case .caution:
            return 1
        case .unstable:
            return 2
        }
    }

    private static func gateStatusPasses(_ status: MotionReleaseGateStatus, allowAttention: Bool) -> Bool {
        switch status {
        case .ready:
            return true
        case .attention:
            return allowAttention
        case .blocked:
            return false
        }
    }

    private static func jsonString<T: Encodable>(_ value: T, pretty: Bool) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(value)
        guard let output = String(data: data, encoding: .utf8) else {
            throw CLIError("failed to encode JSON output")
        }
        return output
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func writeStdout(_ text: String) {
        if let data = text.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    private static func writeStderr(_ text: String) {
        if let data = text.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private enum Command {
        case check(AgentCheckOptions)
        case benchmark(AgentBenchmarkOptions)
        case help
    }

    struct AgentCheckOptions {
        var workspacePath: String?
        var minRuns: Int = 5
        var requireGrade: MotionBenchmarkGrade = .b
        var requireQuality: MotionQualityLevel = .healthy
        var allowAttention = false
        var pretty = false
        var exportMarkdownPath: String?
    }

    struct AgentBenchmarkOptions {
        var preset: MotionPreset = .balanced
        var pretty = false
    }

    private struct ExecutionResult {
        let output: String
        let exitCode: Int32
    }

    private struct CheckExecutionResult {
        let payload: AgentCheckPayload
        let exitCode: Int32
    }

    struct AgentCheckPayload: Encodable, Equatable {
        let schemaVersion: Int
        let generatedAt: String
        let workspacePath: String
        let activeProfile: String?
        let releaseGateStatus: String
        let qualityLevel: String
        let benchmarkGrade: String?
        let runCount: Int
        let benchmarkHistoryCount: Int
        let passed: Bool
        let policyFailures: [String]
        let gateFindings: [String]
        let benchmarkOverallScore: Double?
        let benchmarkConsistencyScore: Double?
        let regressionStatus: String?
        let thresholds: ThresholdPayload
    }

    struct ThresholdPayload: Encodable, Equatable {
        let minRuns: Int
        let requireGrade: String
        let requireQuality: String
        let allowAttention: Bool
    }

    struct AgentBenchmarkPayload: Encodable, Equatable {
        let schemaVersion: Int
        let generatedAt: String
        let preset: String
        let grade: String
        let overallScore: Double
        let consistencyScore: Double
        let qualityLevel: String
        let scenarios: [AgentScenarioPayload]
    }

    struct AgentScenarioPayload: Encodable, Equatable {
        let name: String
        let trigger: String
        let estimatedDuration: Double
        let score: Double
    }

    private enum ExitCode: Int32 {
        case success = 0
        case failedGate = 2
        case usage = 64
    }

    private struct CLIError: LocalizedError {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? {
            message
        }
    }

    static let helpText = """
    liquid-frames agent mode

    Commands:
      --agent check [--workspace PATH] [--min-runs N] [--require-grade A|B|C|D] [--require-quality healthy|caution|unstable] [--allow-attention] [--export-markdown PATH] [--pretty]
      --agent benchmark [--preset balanced|responsive|cinematic] [--pretty]
      --agent help

    Exit codes:
      0   success / policy passed
      2   policy failed
      64  usage error
    """
}
