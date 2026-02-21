import CoreGraphics
import Foundation

struct MotionTuning: Equatable {
    var splitStiffness: Double = 180
    var splitDamping: Double = 22
    var settleStiffness: Double = 145
    var settleDamping: Double = 14

    var preSplitDelay: Double = 0.32
    var gestureCommitDelay: Double = 0.10
    var preSettleDelay: Double = 0.56
    var postSettleDelay: Double = 0.42

    var gestureThreshold: CGFloat = 0.62
    var pullDistance: CGFloat = 210
    var velocityScale: CGFloat = 160
    var velocityInfluence: CGFloat = 0.72
    var biasInfluence: CGFloat = 0.45

    static let splitStiffnessRange: ClosedRange<Double> = 120...280
    static let splitDampingRange: ClosedRange<Double> = 10...34
    static let settleStiffnessRange: ClosedRange<Double> = 90...230
    static let settleDampingRange: ClosedRange<Double> = 8...28
    static let preSplitDelayRange: ClosedRange<Double> = 0...0.8
    static let gestureCommitDelayRange: ClosedRange<Double> = 0...0.35
    static let preSettleDelayRange: ClosedRange<Double> = 0.2...1.2
    static let postSettleDelayRange: ClosedRange<Double> = 0.16...0.9
    static let gestureThresholdRange: ClosedRange<CGFloat> = 0.4...0.9
    static let pullDistanceRange: ClosedRange<CGFloat> = 120...320
    static let velocityScaleRange: ClosedRange<CGFloat> = 80...300
    static let velocityInfluenceRange: ClosedRange<CGFloat> = 0.2...1.2
    static let biasInfluenceRange: ClosedRange<CGFloat> = 0.1...1

    func normalized() -> MotionTuning {
        var copy = self
        copy.splitStiffness = copy.splitStiffness.clamped(to: Self.splitStiffnessRange)
        copy.splitDamping = copy.splitDamping.clamped(to: Self.splitDampingRange)
        copy.settleStiffness = copy.settleStiffness.clamped(to: Self.settleStiffnessRange)
        copy.settleDamping = copy.settleDamping.clamped(to: Self.settleDampingRange)
        copy.preSplitDelay = copy.preSplitDelay.clamped(to: Self.preSplitDelayRange)
        copy.gestureCommitDelay = copy.gestureCommitDelay.clamped(to: Self.gestureCommitDelayRange)
        copy.preSettleDelay = copy.preSettleDelay.clamped(to: Self.preSettleDelayRange)
        copy.postSettleDelay = copy.postSettleDelay.clamped(to: Self.postSettleDelayRange)
        copy.gestureThreshold = copy.gestureThreshold.clamped(to: Self.gestureThresholdRange)
        copy.pullDistance = copy.pullDistance.clamped(to: Self.pullDistanceRange)
        copy.velocityScale = copy.velocityScale.clamped(to: Self.velocityScaleRange)
        copy.velocityInfluence = copy.velocityInfluence.clamped(to: Self.velocityInfluenceRange)
        copy.biasInfluence = copy.biasInfluence.clamped(to: Self.biasInfluenceRange)
        return copy
    }
}

enum MotionPreset: String, CaseIterable, Identifiable, Codable {
    case balanced
    case responsive
    case cinematic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced:
            "Balanced"
        case .responsive:
            "Responsive"
        case .cinematic:
            "Cinematic"
        }
    }

    var tuning: MotionTuning {
        switch self {
        case .balanced:
            MotionTuning()
        case .responsive:
            MotionTuning(
                splitStiffness: 210,
                splitDamping: 20,
                settleStiffness: 172,
                settleDamping: 12,
                preSplitDelay: 0.2,
                gestureCommitDelay: 0.06,
                preSettleDelay: 0.46,
                postSettleDelay: 0.3,
                gestureThreshold: 0.58,
                pullDistance: 185,
                velocityScale: 145,
                velocityInfluence: 0.8,
                biasInfluence: 0.42
            )
        case .cinematic:
            MotionTuning(
                splitStiffness: 156,
                splitDamping: 23,
                settleStiffness: 128,
                settleDamping: 16,
                preSplitDelay: 0.44,
                gestureCommitDelay: 0.12,
                preSettleDelay: 0.74,
                postSettleDelay: 0.52,
                gestureThreshold: 0.65,
                pullDistance: 238,
                velocityScale: 182,
                velocityInfluence: 0.66,
                biasInfluence: 0.5
            )
        }
    }
}

enum MotionTrigger: String, Codable {
    case gesture
    case button
    case replay
}

struct MotionPhaseDurations: Equatable, Codable {
    let preSplit: Double
    let preSettle: Double
    let settleTail: Double

    var total: Double {
        preSplit + preSettle + settleTail
    }
}

struct MotionRunMetrics: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let trigger: MotionTrigger
    let prepPeak: CGFloat
    let velocityPeak: CGFloat
    let biasPeak: CGFloat
    let phases: MotionPhaseDurations

    var totalDuration: Double {
        phases.total
    }
}

enum MotionQualityLevel: String, Codable {
    case healthy
    case caution
    case unstable
}

struct MotionQualityReport: Equatable {
    let level: MotionQualityLevel
    let messages: [String]
}

enum MotionQualityEvaluator {
    static func evaluate(tuning: MotionTuning, recentRuns: [MotionRunMetrics]) -> MotionQualityReport {
        var score = 0
        var messages: [String] = []

        let springRatio = tuning.splitStiffness / max(1, tuning.splitDamping)
        if springRatio < 5.8 {
            score += 1
            messages.append("Split spring ratio is low. Motion may feel heavy or muddy.")
        }

        if tuning.preSettleDelay + tuning.postSettleDelay > 1.55 {
            score += 1
            messages.append("Combined settle delays are high. End-to-end latency may feel slow.")
        }

        if tuning.gestureThreshold > 0.82 {
            score += 1
            messages.append("Gesture threshold is high. Branch initiation may feel unresponsive.")
        }

        if tuning.velocityInfluence > 1.0 {
            score += 1
            messages.append("Velocity influence is very high. Behavior may become inconsistent.")
        }

        let sample = Array(recentRuns.prefix(8))
        if sample.count >= 3 {
            let durations = sample.map(\.totalDuration)
            let mean = durations.reduce(0, +) / Double(durations.count)
            let variance = durations
                .map { pow($0 - mean, 2) }
                .reduce(0, +) / Double(durations.count)
            let deviation = sqrt(variance)

            if mean > 1.85 {
                score += 2
                messages.append("Recent runs are too slow on average.")
            }
            if deviation > 0.3 {
                score += 2
                messages.append("Run timing variance is high. Motion is not yet reliable.")
            }
        }

        let level: MotionQualityLevel
        switch score {
        case ..<1:
            level = .healthy
        case 1...2:
            level = .caution
        default:
            level = .unstable
        }

        if messages.isEmpty {
            messages.append("Motion profile is within target reliability bounds.")
        }

        return MotionQualityReport(level: level, messages: messages)
    }
}

enum MotionAdaptiveEngine {
    static func adapt(tuning: MotionTuning, basedOn run: MotionRunMetrics) -> MotionTuning {
        var next = tuning
        let targetDuration = 1.35

        if run.totalDuration > targetDuration + 0.18 {
            next.splitStiffness *= 1.04
            next.settleStiffness *= 1.05
            next.preSettleDelay *= 0.93
            next.postSettleDelay *= 0.9
        } else if run.totalDuration < targetDuration - 0.2 {
            next.splitDamping *= 1.04
            next.settleDamping *= 1.05
            next.preSettleDelay *= 1.03
            next.postSettleDelay *= 1.03
        }

        if run.velocityPeak > 0.82 {
            next.velocityInfluence *= 0.96
            next.gestureThreshold += 0.01
        }

        if abs(run.biasPeak) > 0.82 {
            next.biasInfluence *= 0.95
        }

        if run.prepPeak < 0.74 && run.trigger == .gesture {
            next.gestureThreshold -= 0.01
            next.pullDistance *= 0.98
        }

        return next.normalized()
    }
}

struct MotionProfile: Identifiable, Equatable {
    let id: UUID
    var name: String
    var notes: String
    var tags: [String]
    var tuning: MotionTuning
    var baseline: MotionBenchmarkBaseline?
    var createdAt: Date
    var updatedAt: Date

    static func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Profile" : trimmed
    }

    static func normalizedNotes(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let dedupeKey = trimmed.lowercased()
            guard seen.insert(dedupeKey).inserted else { continue }
            output.append(trimmed)
        }
        return output
    }

    static func normalizedTagsCSV(_ value: String) -> [String] {
        normalizedTags(value.split(separator: ",").map { String($0) })
    }

    var tagCSV: String {
        tags.joined(separator: ", ")
    }

    func withNormalizedMetadata() -> MotionProfile {
        var copy = self
        copy.name = Self.normalizedName(copy.name)
        copy.notes = Self.normalizedNotes(copy.notes)
        copy.tags = Self.normalizedTags(copy.tags)
        return copy
    }

    func metadataMatchesDraft(name: String, notes: String, tags: [String]) -> Bool {
        self.name == Self.normalizedName(name) &&
            self.notes == Self.normalizedNotes(notes) &&
            self.tags == Self.normalizedTags(tags)
    }
}

struct MotionWorkspaceSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var selectedPresetRawValue: String
    var autoAdaptEnabled: Bool
    var tuning: MotionTuningRecord
    var runHistory: [MotionRunRecord]
    var profiles: [MotionProfileRecord]
    var activeProfileID: String?
    var benchmarkHistory: [MotionBenchmarkRecord]
    var latestBenchmark: MotionBenchmarkRecord?
    var savedAt: Date

    init(
        schemaVersion: Int = 2,
        selectedPresetRawValue: String,
        autoAdaptEnabled: Bool,
        tuning: MotionTuningRecord,
        runHistory: [MotionRunRecord],
        profiles: [MotionProfileRecord],
        activeProfileID: String?,
        benchmarkHistory: [MotionBenchmarkRecord],
        latestBenchmark: MotionBenchmarkRecord?,
        savedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.selectedPresetRawValue = selectedPresetRawValue
        self.autoAdaptEnabled = autoAdaptEnabled
        self.tuning = tuning
        self.runHistory = runHistory
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.benchmarkHistory = benchmarkHistory
        self.latestBenchmark = latestBenchmark
        self.savedAt = savedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case selectedPresetRawValue
        case autoAdaptEnabled
        case tuning
        case runHistory
        case profiles
        case activeProfileID
        case benchmarkHistory
        case latestBenchmark
        case savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        selectedPresetRawValue = try container.decodeIfPresent(
            String.self,
            forKey: .selectedPresetRawValue
        ) ?? MotionPreset.balanced.rawValue
        autoAdaptEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoAdaptEnabled) ?? true
        tuning = try container.decodeIfPresent(MotionTuningRecord.self, forKey: .tuning)
            ?? MotionTuningRecord(tuning: MotionPreset.balanced.tuning)
        runHistory = try container.decodeIfPresent([MotionRunRecord].self, forKey: .runHistory) ?? []
        profiles = try container.decodeIfPresent([MotionProfileRecord].self, forKey: .profiles) ?? []
        activeProfileID = try container.decodeIfPresent(String.self, forKey: .activeProfileID)
        benchmarkHistory = try container.decodeIfPresent([MotionBenchmarkRecord].self, forKey: .benchmarkHistory) ?? []
        latestBenchmark = try container.decodeIfPresent(MotionBenchmarkRecord.self, forKey: .latestBenchmark)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(selectedPresetRawValue, forKey: .selectedPresetRawValue)
        try container.encode(autoAdaptEnabled, forKey: .autoAdaptEnabled)
        try container.encode(tuning, forKey: .tuning)
        try container.encode(runHistory, forKey: .runHistory)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(activeProfileID, forKey: .activeProfileID)
        try container.encode(benchmarkHistory, forKey: .benchmarkHistory)
        try container.encode(latestBenchmark, forKey: .latestBenchmark)
        try container.encode(savedAt, forKey: .savedAt)
    }
}

struct MotionTuningRecord: Codable, Equatable {
    var splitStiffness: Double
    var splitDamping: Double
    var settleStiffness: Double
    var settleDamping: Double
    var preSplitDelay: Double
    var gestureCommitDelay: Double
    var preSettleDelay: Double
    var postSettleDelay: Double
    var gestureThreshold: Double
    var pullDistance: Double
    var velocityScale: Double
    var velocityInfluence: Double
    var biasInfluence: Double

    init(tuning: MotionTuning) {
        splitStiffness = tuning.splitStiffness
        splitDamping = tuning.splitDamping
        settleStiffness = tuning.settleStiffness
        settleDamping = tuning.settleDamping
        preSplitDelay = tuning.preSplitDelay
        gestureCommitDelay = tuning.gestureCommitDelay
        preSettleDelay = tuning.preSettleDelay
        postSettleDelay = tuning.postSettleDelay
        gestureThreshold = Double(tuning.gestureThreshold)
        pullDistance = Double(tuning.pullDistance)
        velocityScale = Double(tuning.velocityScale)
        velocityInfluence = Double(tuning.velocityInfluence)
        biasInfluence = Double(tuning.biasInfluence)
    }

    var tuning: MotionTuning {
        MotionTuning(
            splitStiffness: splitStiffness,
            splitDamping: splitDamping,
            settleStiffness: settleStiffness,
            settleDamping: settleDamping,
            preSplitDelay: preSplitDelay,
            gestureCommitDelay: gestureCommitDelay,
            preSettleDelay: preSettleDelay,
            postSettleDelay: postSettleDelay,
            gestureThreshold: CGFloat(gestureThreshold),
            pullDistance: CGFloat(pullDistance),
            velocityScale: CGFloat(velocityScale),
            velocityInfluence: CGFloat(velocityInfluence),
            biasInfluence: CGFloat(biasInfluence)
        )
    }
}

struct MotionProfileRecord: Codable, Equatable {
    var id: String
    var name: String
    var notes: String
    var tags: [String]
    var tuning: MotionTuningRecord
    var baseline: MotionBenchmarkBaseline?
    var createdAt: Date
    var updatedAt: Date

    init(profile: MotionProfile) {
        let normalized = profile.withNormalizedMetadata()
        id = normalized.id.uuidString
        name = normalized.name
        notes = normalized.notes
        tags = normalized.tags
        tuning = MotionTuningRecord(tuning: normalized.tuning)
        baseline = normalized.baseline
        createdAt = normalized.createdAt
        updatedAt = normalized.updatedAt
    }

    var profile: MotionProfile {
        MotionProfile(
            id: UUID(uuidString: id) ?? UUID(),
            name: MotionProfile.normalizedName(name),
            notes: MotionProfile.normalizedNotes(notes),
            tags: MotionProfile.normalizedTags(tags),
            tuning: tuning.tuning,
            baseline: baseline,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case tags
        case tuning
        case baseline
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Imported"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        tuning = try container.decode(MotionTuningRecord.self, forKey: .tuning)
        baseline = try container.decodeIfPresent(MotionBenchmarkBaseline.self, forKey: .baseline)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
        try container.encode(tuning, forKey: .tuning)
        try container.encode(baseline, forKey: .baseline)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct MotionRunRecord: Codable, Equatable {
    var timestamp: Date
    var triggerRawValue: String
    var prepPeak: Double
    var velocityPeak: Double
    var biasPeak: Double
    var preSplit: Double
    var preSettle: Double
    var settleTail: Double

    init(metrics: MotionRunMetrics) {
        timestamp = metrics.timestamp
        triggerRawValue = metrics.trigger.rawValue
        prepPeak = Double(metrics.prepPeak)
        velocityPeak = Double(metrics.velocityPeak)
        biasPeak = Double(metrics.biasPeak)
        preSplit = metrics.phases.preSplit
        preSettle = metrics.phases.preSettle
        settleTail = metrics.phases.settleTail
    }

    var metrics: MotionRunMetrics {
        MotionRunMetrics(
            timestamp: timestamp,
            trigger: MotionTrigger(rawValue: triggerRawValue) ?? .button,
            prepPeak: CGFloat(prepPeak),
            velocityPeak: CGFloat(velocityPeak),
            biasPeak: CGFloat(biasPeak),
            phases: MotionPhaseDurations(
                preSplit: preSplit,
                preSettle: preSettle,
                settleTail: settleTail
            )
        )
    }
}

struct MotionBenchmarkScenarioRecord: Codable, Equatable {
    var scenarioName: String
    var triggerRawValue: String
    var estimatedDuration: Double
    var responsiveness: Double
    var stability: Double
    var score: Double

    init(scenario: MotionBenchmarkScenarioResult) {
        scenarioName = scenario.scenarioName
        triggerRawValue = scenario.trigger.rawValue
        estimatedDuration = scenario.estimatedDuration
        responsiveness = scenario.responsiveness
        stability = scenario.stability
        score = scenario.score
    }

    var scenario: MotionBenchmarkScenarioResult {
        MotionBenchmarkScenarioResult(
            scenarioName: scenarioName,
            trigger: MotionTrigger(rawValue: triggerRawValue) ?? .button,
            estimatedDuration: estimatedDuration,
            responsiveness: responsiveness,
            stability: stability,
            score: score
        )
    }
}

struct MotionBenchmarkRecord: Codable, Equatable {
    var generatedAt: Date
    var overallScore: Double
    var consistencyScore: Double
    var gradeRawValue: String
    var scenarios: [MotionBenchmarkScenarioRecord]
    var qualityLevelRawValue: String
    var qualityMessages: [String]

    init(report: MotionBenchmarkReport) {
        generatedAt = report.generatedAt
        overallScore = report.overallScore
        consistencyScore = report.consistencyScore
        gradeRawValue = report.grade.rawValue
        scenarios = report.scenarios.map(MotionBenchmarkScenarioRecord.init(scenario:))
        qualityLevelRawValue = report.quality.level.rawValue
        qualityMessages = report.quality.messages
    }

    var report: MotionBenchmarkReport {
        MotionBenchmarkReport(
            generatedAt: generatedAt,
            overallScore: overallScore,
            consistencyScore: consistencyScore,
            grade: MotionBenchmarkGrade(rawValue: gradeRawValue) ?? .d,
            scenarios: scenarios.map(\.scenario),
            quality: MotionQualityReport(
                level: MotionQualityLevel(rawValue: qualityLevelRawValue) ?? .caution,
                messages: qualityMessages
            )
        )
    }
}

enum MotionBenchmarkGrade: String, Codable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
}

struct MotionBenchmarkScenarioResult: Equatable, Identifiable {
    let scenarioName: String
    let trigger: MotionTrigger
    let estimatedDuration: Double
    let responsiveness: Double
    let stability: Double
    let score: Double

    var id: String {
        scenarioName
    }
}

struct MotionBenchmarkReport: Equatable, Identifiable {
    let generatedAt: Date
    let overallScore: Double
    let consistencyScore: Double
    let grade: MotionBenchmarkGrade
    let scenarios: [MotionBenchmarkScenarioResult]
    let quality: MotionQualityReport

    var id: Date {
        generatedAt
    }
}

struct MotionBenchmarkBaseline: Codable, Equatable {
    let generatedAt: Date
    let overallScore: Double
    let consistencyScore: Double
    let gradeRawValue: String
    let scenarioScores: [String: Double]

    init(report: MotionBenchmarkReport) {
        generatedAt = report.generatedAt
        overallScore = report.overallScore
        consistencyScore = report.consistencyScore
        gradeRawValue = report.grade.rawValue
        scenarioScores = report.scenarios.reduce(into: [:]) { partial, scenario in
            partial[scenario.scenarioName] = scenario.score
        }
    }

    var grade: MotionBenchmarkGrade {
        MotionBenchmarkGrade(rawValue: gradeRawValue) ?? .d
    }
}

enum MotionBenchmarkRegressionStatus: String {
    case pass
    case warning
    case fail
}

struct MotionBenchmarkRegression: Equatable {
    let status: MotionBenchmarkRegressionStatus
    let overallDelta: Double
    let consistencyDelta: Double
    let worstScenarioDelta: Double
    let messages: [String]
}

enum MotionBenchmarkRegressionEvaluator {
    static func compare(
        report: MotionBenchmarkReport,
        baseline: MotionBenchmarkBaseline
    ) -> MotionBenchmarkRegression {
        let overallDelta = report.overallScore - baseline.overallScore
        let consistencyDelta = report.consistencyScore - baseline.consistencyScore

        let scenarioDeltas = report.scenarios.map { scenario -> Double in
            let baselineScore = baseline.scenarioScores[scenario.scenarioName] ?? scenario.score
            return scenario.score - baselineScore
        }
        let worstScenarioDelta = scenarioDeltas.min() ?? 0

        var messages: [String] = []
        if overallDelta < -6 {
            messages.append("Overall benchmark score regressed significantly.")
        } else if overallDelta < -2.5 {
            messages.append("Overall benchmark score regressed mildly.")
        } else if overallDelta > 2.5 {
            messages.append("Overall benchmark score improved.")
        }

        if consistencyDelta < -6 {
            messages.append("Consistency score regressed.")
        } else if consistencyDelta > 4 {
            messages.append("Consistency score improved.")
        }

        if worstScenarioDelta < -12 {
            messages.append("At least one benchmark scenario regressed heavily.")
        } else if worstScenarioDelta < -6 {
            messages.append("One or more scenarios regressed.")
        }

        let status: MotionBenchmarkRegressionStatus
        if overallDelta < -6 || consistencyDelta < -8 || worstScenarioDelta < -12 {
            status = .fail
        } else if overallDelta < -2.5 || consistencyDelta < -4 || worstScenarioDelta < -6 {
            status = .warning
        } else {
            status = .pass
        }

        if messages.isEmpty {
            messages.append("Benchmark is stable against baseline.")
        }

        return MotionBenchmarkRegression(
            status: status,
            overallDelta: overallDelta,
            consistencyDelta: consistencyDelta,
            worstScenarioDelta: worstScenarioDelta,
            messages: messages
        )
    }
}

enum MotionWorkspaceMerger {
    static func merge(
        current: MotionWorkspaceSnapshot,
        incoming: MotionWorkspaceSnapshot
    ) -> MotionWorkspaceSnapshot {
        let authority = incoming.savedAt >= current.savedAt ? incoming : current
        let mergedProfiles = mergeProfiles(current: current.profiles, incoming: incoming.profiles)
        let mergedRuns = mergeRuns(current: current.runHistory, incoming: incoming.runHistory)
        let mergedBenchmarks = mergeBenchmarks(
            current: current.benchmarkHistory,
            incoming: incoming.benchmarkHistory
        )
        let latestBenchmark = [incoming.latestBenchmark, current.latestBenchmark, mergedBenchmarks.first]
            .compactMap { $0 }
            .max(by: { $0.generatedAt < $1.generatedAt })
        let activeProfileID = resolveActiveProfileID(
            candidates: [
                incoming.activeProfileID,
                authority.activeProfileID,
                current.activeProfileID
            ],
            mergedProfiles: mergedProfiles
        )

        return MotionWorkspaceSnapshot(
            schemaVersion: max(2, max(current.schemaVersion, incoming.schemaVersion)),
            selectedPresetRawValue: authority.selectedPresetRawValue,
            autoAdaptEnabled: authority.autoAdaptEnabled,
            tuning: authority.tuning,
            runHistory: mergedRuns,
            profiles: mergedProfiles,
            activeProfileID: activeProfileID,
            benchmarkHistory: mergedBenchmarks,
            latestBenchmark: latestBenchmark,
            savedAt: max(current.savedAt, incoming.savedAt)
        )
    }

    private static func mergeProfiles(
        current: [MotionProfileRecord],
        incoming: [MotionProfileRecord]
    ) -> [MotionProfileRecord] {
        var merged: [String: MotionProfileRecord] = [:]

        func upsert(_ record: MotionProfileRecord, preferCurrent: Bool) {
            let normalized = MotionProfileRecord(profile: record.profile.withNormalizedMetadata())
            if let existing = merged[normalized.id] {
                if normalized.updatedAt > existing.updatedAt {
                    merged[normalized.id] = normalized
                } else if normalized.updatedAt == existing.updatedAt, !preferCurrent {
                    merged[normalized.id] = normalized
                }
            } else {
                merged[normalized.id] = normalized
            }
        }

        for record in current {
            upsert(record, preferCurrent: true)
        }
        for record in incoming {
            upsert(record, preferCurrent: false)
        }

        return merged.values.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private static func mergeRuns(
        current: [MotionRunRecord],
        incoming: [MotionRunRecord]
    ) -> [MotionRunRecord] {
        var seen = Set<String>()
        var merged: [MotionRunRecord] = []
        for run in (current + incoming).sorted(by: { $0.timestamp > $1.timestamp }) {
            let key = runKey(run)
            guard seen.insert(key).inserted else { continue }
            merged.append(run)
            if merged.count == 40 {
                break
            }
        }
        return merged
    }

    private static func mergeBenchmarks(
        current: [MotionBenchmarkRecord],
        incoming: [MotionBenchmarkRecord]
    ) -> [MotionBenchmarkRecord] {
        var seen = Set<String>()
        var merged: [MotionBenchmarkRecord] = []
        for benchmark in (current + incoming).sorted(by: { $0.generatedAt > $1.generatedAt }) {
            let key = benchmarkKey(benchmark)
            guard seen.insert(key).inserted else { continue }
            merged.append(benchmark)
            if merged.count == 24 {
                break
            }
        }
        return merged
    }

    private static func resolveActiveProfileID(
        candidates: [String?],
        mergedProfiles: [MotionProfileRecord]
    ) -> String? {
        let ids = Set(mergedProfiles.map(\.id))
        for candidate in candidates {
            if let candidate, ids.contains(candidate) {
                return candidate
            }
        }
        return mergedProfiles.first?.id
    }

    private static func runKey(_ run: MotionRunRecord) -> String {
        "\(run.timestamp.timeIntervalSince1970)-\(run.triggerRawValue)-\(quantized(run.prepPeak))-\(quantized(run.velocityPeak))-\(quantized(run.biasPeak))-\(quantized(run.preSplit))-\(quantized(run.preSettle))-\(quantized(run.settleTail))"
    }

    private static func benchmarkKey(_ benchmark: MotionBenchmarkRecord) -> String {
        "\(benchmark.generatedAt.timeIntervalSince1970)-\(quantized(benchmark.overallScore))-\(quantized(benchmark.consistencyScore))-\(benchmark.gradeRawValue)"
    }

    private static func quantized(_ value: Double) -> Int {
        Int((value * 1000).rounded())
    }
}

enum MotionReleaseGateStatus: String {
    case ready = "READY"
    case attention = "ATTENTION"
    case blocked = "BLOCKED"
}

struct MotionReleaseGateReport: Equatable {
    let generatedAt: Date
    let workspacePath: String
    let profile: MotionProfile
    let profileIsDirty: Bool
    let quality: MotionQualityReport
    let benchmark: MotionBenchmarkReport?
    let regression: MotionBenchmarkRegression?
    let latestRun: MotionRunMetrics?
    let runCount: Int
    let benchmarkHistoryCount: Int

    var status: MotionReleaseGateStatus {
        if profileIsDirty { return .blocked }
        if quality.level == .unstable { return .blocked }
        if let benchmark, benchmark.grade == .c || benchmark.grade == .d { return .blocked }
        if regression?.status == .fail { return .blocked }

        if quality.level == .caution { return .attention }
        if benchmark == nil { return .attention }
        if regression == nil || regression?.status == .warning { return .attention }
        if runCount < 5 { return .attention }
        return .ready
    }

    var findings: [String] {
        var output: [String] = []

        if profileIsDirty {
            output.append("Active profile has unsaved edits.")
        }

        switch quality.level {
        case .healthy:
            break
        case .caution:
            output.append("Quality evaluator is in CAUTION.")
        case .unstable:
            output.append("Quality evaluator is UNSTABLE.")
        }

        if let benchmark {
            if benchmark.grade == .c || benchmark.grade == .d {
                output.append("Benchmark grade \(benchmark.grade.rawValue) is below release target.")
            }
        } else {
            output.append("No benchmark report is available.")
        }

        if let regression {
            switch regression.status {
            case .pass:
                break
            case .warning:
                output.append("Regression gate is WARNING.")
            case .fail:
                output.append("Regression gate is FAIL.")
            }
        } else {
            output.append("No baseline regression check is available.")
        }

        if runCount < 5 {
            output.append("Run sample size is low (\(runCount)); recommend at least 5 runs.")
        }

        return output
    }

    var markdown: String {
        var lines: [String] = []
        lines.append("# liquid-frames Release Gate")
        lines.append("")
        lines.append("- Generated At: \(Self.isoString(from: generatedAt))")
        lines.append("- Workspace: `\(workspacePath)`")
        lines.append("- Active Profile: \(profile.name)")
        lines.append("- Profile Tags: \(profile.tags.isEmpty ? "none" : profile.tags.joined(separator: ", "))")
        lines.append("")
        lines.append("## Gate Status")
        lines.append("")
        lines.append("**\(status.rawValue)**")
        lines.append("")
        lines.append("## Findings")
        lines.append("")

        if findings.isEmpty {
            lines.append("- No blockers or warnings detected.")
        } else {
            for finding in findings {
                lines.append("- \(finding)")
            }
        }

        lines.append("")
        lines.append("## Quality")
        lines.append("")
        lines.append("- Level: \(quality.level.rawValue.uppercased())")
        for message in quality.messages {
            lines.append("- \(message)")
        }

        lines.append("")
        lines.append("## Benchmark")
        lines.append("")
        if let benchmark {
            lines.append("- Grade: \(benchmark.grade.rawValue)")
            lines.append("- Overall Score: \(Self.number(benchmark.overallScore, digits: 1))")
            lines.append("- Consistency Score: \(Self.number(benchmark.consistencyScore, digits: 1))")
            lines.append("- Scenarios:")
            for scenario in benchmark.scenarios {
                lines.append("  - \(scenario.scenarioName): \(Self.number(scenario.score, digits: 1))")
            }
        } else {
            lines.append("- Not available")
        }

        lines.append("")
        lines.append("## Regression")
        lines.append("")
        if let regression {
            lines.append("- Status: \(regression.status.rawValue.uppercased())")
            lines.append("- Δ Overall: \(Self.number(regression.overallDelta, digits: 1))")
            lines.append("- Δ Consistency: \(Self.number(regression.consistencyDelta, digits: 1))")
            lines.append("- Worst Scenario Δ: \(Self.number(regression.worstScenarioDelta, digits: 1))")
            for message in regression.messages {
                lines.append("- \(message)")
            }
        } else {
            lines.append("- Not available")
        }

        lines.append("")
        lines.append("## Recent Activity")
        lines.append("")
        lines.append("- Run Count: \(runCount)")
        lines.append("- Benchmark History Count: \(benchmarkHistoryCount)")
        if let latestRun {
            lines.append("- Latest Run Trigger: \(latestRun.trigger.rawValue)")
            lines.append("- Latest Run Duration: \(Self.number(latestRun.totalDuration, digits: 2))s")
        }

        return lines.joined(separator: "\n")
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func number(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}

enum MotionBenchmarkEngine {
    static func runSuite(tuning: MotionTuning) -> MotionBenchmarkReport {
        let normalized = tuning.normalized()
        let scenarios = benchmarkSamples().map { sample in
            buildScenarioResult(sample: sample, tuning: normalized)
        }

        let overall = scenarios.map(\.score).average
        let durationDeviation = scenarios.map(\.estimatedDuration).standardDeviation
        let consistency = (1 - (durationDeviation / 0.38)).clamped(to: 0...1) * 100

        let syntheticRuns = scenarios.map { scenario in
            MotionRunMetrics(
                timestamp: Date(),
                trigger: scenario.trigger,
                prepPeak: 1,
                velocityPeak: CGFloat(0.35 + (scenario.responsiveness * 0.5)),
                biasPeak: 0,
                phases: MotionPhaseDurations(
                    preSplit: scenario.estimatedDuration * 0.28,
                    preSettle: scenario.estimatedDuration * 0.44,
                    settleTail: scenario.estimatedDuration * 0.28
                )
            )
        }

        let quality = MotionQualityEvaluator.evaluate(tuning: normalized, recentRuns: syntheticRuns)
        let combinedScore = ((overall * 0.75) + (consistency * 0.25)).clamped(to: 0...100)
        let grade: MotionBenchmarkGrade
        switch combinedScore {
        case 88...:
            grade = .a
        case 75..<88:
            grade = .b
        case 62..<75:
            grade = .c
        default:
            grade = .d
        }

        return MotionBenchmarkReport(
            generatedAt: Date(),
            overallScore: combinedScore,
            consistencyScore: consistency,
            grade: grade,
            scenarios: scenarios,
            quality: quality
        )
    }

    private static func buildScenarioResult(
        sample: MotionBenchmarkSample,
        tuning: MotionTuning
    ) -> MotionBenchmarkScenarioResult {
        let signal = GestureSignalEstimator.estimate(
            input: GestureSignalInput(
                translation: sample.translation,
                predictedEndTranslation: sample.predictedEndTranslation,
                tuning: tuning
            )
        )

        let splitResponse = (165 / tuning.splitStiffness) + (tuning.splitDamping / 118)
        let settleResponse = (180 / tuning.settleStiffness) + (tuning.settleDamping / 108)
        let baseDuration = tuning.preSplitDelay + tuning.preSettleDelay + tuning.postSettleDelay
        let gestureReadiness = max(0.78, Double(signal.prepProgress) + 0.22)
        let totalDuration = (baseDuration + splitResponse + settleResponse) / gestureReadiness

        let targetDuration = sample.targetDuration
        let responsiveness = (1 - abs(totalDuration - targetDuration) / targetDuration).clamped(to: 0...1)
        let springRatio = tuning.splitStiffness / max(1, tuning.splitDamping)
        let ratioStability = (1 - abs(springRatio - 8.2) / 8.2).clamped(to: 0...1)
        let velocityPenalty = max(0, Double(tuning.velocityInfluence - 0.9) * 0.42)
        let stability = (ratioStability - velocityPenalty).clamped(to: 0...1)

        let score = ((responsiveness * 0.56) + (stability * 0.44)) * 100
        return MotionBenchmarkScenarioResult(
            scenarioName: sample.name,
            trigger: sample.trigger,
            estimatedDuration: totalDuration,
            responsiveness: responsiveness,
            stability: stability,
            score: score.clamped(to: 0...100)
        )
    }

    private static func benchmarkSamples() -> [MotionBenchmarkSample] {
        [
            MotionBenchmarkSample(
                name: "Gentle Gesture",
                trigger: .gesture,
                translation: CGSize(width: 8, height: -160),
                predictedEndTranslation: CGSize(width: 24, height: -210),
                targetDuration: 1.42
            ),
            MotionBenchmarkSample(
                name: "Assertive Gesture",
                trigger: .gesture,
                translation: CGSize(width: 0, height: -250),
                predictedEndTranslation: CGSize(width: 10, height: -340),
                targetDuration: 1.24
            ),
            MotionBenchmarkSample(
                name: "Lateral Bias Gesture",
                trigger: .gesture,
                translation: CGSize(width: 120, height: -210),
                predictedEndTranslation: CGSize(width: 168, height: -270),
                targetDuration: 1.34
            ),
            MotionBenchmarkSample(
                name: "Button Trigger",
                trigger: .button,
                translation: CGSize(width: 0, height: -220),
                predictedEndTranslation: CGSize(width: 0, height: -220),
                targetDuration: 1.33
            )
        ]
    }
}

private struct MotionBenchmarkSample {
    let name: String
    let trigger: MotionTrigger
    let translation: CGSize
    let predictedEndTranslation: CGSize
    let targetDuration: Double
}

struct GestureSignalInput {
    let translation: CGSize
    let predictedEndTranslation: CGSize
    let tuning: MotionTuning
}

struct GestureSignalOutput: Equatable {
    let prepProgress: CGFloat
    let glowPulse: CGFloat
    let velocity: CGFloat
    let bias: CGFloat
    let energy: CGFloat
}

enum GestureSignalEstimator {
    static func estimate(input: GestureSignalInput) -> GestureSignalOutput {
        let translation = input.translation
        let pull = max(0, -translation.height) + (abs(translation.width) * 0.25)
        let prepProgress = min(1, pull / max(120, input.tuning.pullDistance))

        let projectedDeltaX = input.predictedEndTranslation.width - translation.width
        let projectedDeltaY = input.predictedEndTranslation.height - translation.height
        let projectedDistance = hypot(projectedDeltaX, projectedDeltaY)
        let velocity = min(1, projectedDistance / max(80, input.tuning.velocityScale))

        let horizontalBias = translation.width / max(80, input.tuning.pullDistance * 0.8)
        let projectedBias = projectedDeltaX / max(100, input.tuning.pullDistance)
        let bias = (horizontalBias + (projectedBias * input.tuning.biasInfluence)).clamped(to: -1...1)

        let energy = min(1, (prepProgress * 0.35) + (velocity * input.tuning.velocityInfluence))
        let glowPulse = min(1, (prepProgress * 1.1) + (velocity * 0.2))

        return GestureSignalOutput(
            prepProgress: prepProgress,
            glowPulse: glowPulse,
            velocity: velocity,
            bias: bias,
            energy: energy
        )
    }
}

struct BirthDynamicsState: Equatable {
    let envelope: CGFloat
    let neckConstriction: CGFloat
    let membraneStretch: CGFloat
    let fluidTransfer: CGFloat
    let torsion: CGFloat
    let pulse: CGFloat
    let sheathThickness: CGFloat
    let inhale: CGFloat
    let exhale: CGFloat
    let aperture: CGFloat
    let spitStrength: CGFloat
}

struct SpawnCascadePhases: Equatable {
    let leftBranch: CGFloat
    let rightBranch: CGFloat
    let leftLeaves: [CGFloat]
    let rightLeaves: [CGFloat]

    var chainCoverage: CGFloat {
        let leftMax = leftLeaves.max() ?? 0
        let rightMax = rightLeaves.max() ?? 0
        return Swift.max(Swift.max(leftBranch, rightBranch), Swift.max(leftMax, rightMax))
    }
}

enum SpawnCascadePhaser {
    static func sample(
        progress: CGFloat,
        leftLeafCount: Int,
        rightLeafCount: Int
    ) -> SpawnCascadePhases {
        let t = clamped01(progress)

        let leftBranch = staged(t, start: 0.02, duration: 0.4)
        let rightBranch = staged(t, start: 0.28, duration: 0.4)
        let leftLeaves = stagedSequence(
            t,
            count: max(0, leftLeafCount),
            start: 0.16,
            step: 0.11,
            duration: 0.28
        )
        let rightLeaves = stagedSequence(
            t,
            count: max(0, rightLeafCount),
            start: 0.44,
            step: 0.11,
            duration: 0.28
        )

        return SpawnCascadePhases(
            leftBranch: leftBranch,
            rightBranch: rightBranch,
            leftLeaves: leftLeaves,
            rightLeaves: rightLeaves
        )
    }

    private static func stagedSequence(
        _ progress: CGFloat,
        count: Int,
        start: CGFloat,
        step: CGFloat,
        duration: CGFloat
    ) -> [CGFloat] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            staged(progress, start: start + (CGFloat(index) * step), duration: duration)
        }
    }

    private static func staged(
        _ progress: CGFloat,
        start: CGFloat,
        duration: CGFloat
    ) -> CGFloat {
        guard duration > 0 else { return progress >= start ? 1 : 0 }
        let normalized = clamped01((progress - start) / duration)
        // cubic easing for organic, non-linear reveal.
        return normalized * normalized * (3 - (2 * normalized))
    }

    private static func clamped01(_ value: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(1, value))
    }
}

enum BirthDynamicsEngine {
    static func sample(
        prepProgress: CGFloat,
        splitProgress: CGFloat,
        settleProgress: CGFloat,
        velocity: CGFloat,
        energy: CGFloat,
        bias: CGFloat
    ) -> BirthDynamicsState {
        let prep = clamped01(prepProgress)
        let split = clamped01(splitProgress)
        let settle = clamped01(settleProgress)
        let speed = clamped01(velocity)
        let power = clamped01(energy)
        let signedBias = clampedSigned(bias)

        let prepCurve = 1 - pow(1 - prep, 2.25)
        let splitCurve = smootherStep(split)
        let settleCurve = smootherStep(settle)
        let envelope = clamped01((prepCurve * 0.24) + (splitCurve * 0.76))

        // Breath cycle: prep is inhale pressure, split is exhale/ejection.
        let inhale = clamped01(
            (prepCurve * (1 - splitCurve)) * (1 - (settleCurve * 0.25))
        )
        let exhale = clamped01(
            (splitCurve * (1 - (settleCurve * 0.48))) + (speed * 0.12)
        )

        let pulseCarrier = max(0, splitCurve - (settleCurve * 0.32))
        let pulseDamping = CGFloat(exp(-Double(settleCurve) * 2.9))
        let pulsePhase = Double(splitCurve) * .pi * (2.1 + Double(speed))
        let pulse = CGFloat(sin(pulsePhase)) * pulseDamping * (0.34 + (power * 0.36))

        let throatPressure = clamped01((inhale * 0.6) + (exhale * 0.7) + (abs(pulse) * 0.18))
        let neckConstriction = clamped01(throatPressure - (settleCurve * 0.44))

        let membraneStretch = clamped01(
            (splitCurve * (0.64 + (power * 0.34))) +
                (prepCurve * 0.2) -
                (settleCurve * 0.27)
        )

        let fluidTransfer = clamped01(
            (splitCurve * (0.42 + (power * 0.44))) +
                (pulseCarrier * 0.24) -
                (settleCurve * 0.22)
        )

        let torsion = clampedSigned(
            (signedBias * (0.54 + (speed * 0.25))) +
                (pulse * 0.34)
        )

        let sheathThickness = clamped01(
            0.24 + (fluidTransfer * 0.56) + (abs(pulse) * 0.2)
        )

        let aperture = clamped01(
            0.2 +
                (exhale * 0.68) -
                (inhale * 0.42) +
                (speed * 0.08) -
                (settleCurve * 0.18)
        )

        let spitStrength = clamped01(
            (exhale * (0.72 + (power * 0.28))) + (abs(pulse) * 0.18)
        )

        return BirthDynamicsState(
            envelope: envelope,
            neckConstriction: neckConstriction,
            membraneStretch: membraneStretch,
            fluidTransfer: fluidTransfer,
            torsion: torsion,
            pulse: pulse,
            sheathThickness: sheathThickness,
            inhale: inhale,
            exhale: exhale,
            aperture: aperture,
            spitStrength: spitStrength
        )
    }

    private static func smootherStep(_ value: CGFloat) -> CGFloat {
        let t = clamped01(value)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func clamped01(_ value: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(1, value))
    }

    private static func clampedSigned(_ value: CGFloat) -> CGFloat {
        Swift.max(-1, Swift.min(1, value))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let mean = average
        let variance = map { pow($0 - mean, 2) }.reduce(0, +) / Double(count)
        return sqrt(variance)
    }
}
