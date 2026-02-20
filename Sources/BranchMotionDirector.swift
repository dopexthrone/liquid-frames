import SwiftUI

enum BranchPhase: String {
    case idle
    case gesturing
    case splitting
    case settling
    case branched
}

@MainActor
final class BranchMotionDirector: ObservableObject {
    @Published private(set) var phase: BranchPhase = .idle
    @Published private(set) var prepProgress: CGFloat = 0
    @Published private(set) var splitProgress: CGFloat = 0
    @Published private(set) var settleProgress: CGFloat = 0
    @Published private(set) var glowPulse: CGFloat = 0
    @Published private(set) var showsChildren: Bool = false
    @Published private(set) var gestureVelocity: CGFloat = 0
    @Published private(set) var branchBias: CGFloat = 0
    @Published private(set) var branchEnergy: CGFloat = 0

    @Published private(set) var selectedPreset: MotionPreset = .balanced
    @Published private(set) var tuning: MotionTuning = MotionPreset.balanced.tuning
    @Published private(set) var profiles: [MotionProfile] = []
    @Published private(set) var activeProfileID: UUID?
    @Published private(set) var profileIsDirty = false

    @Published private(set) var runHistory: [MotionRunMetrics] = []
    @Published private(set) var qualityReport = MotionQualityReport(
        level: .healthy,
        messages: ["Motion profile is within target reliability bounds."]
    )
    @Published private(set) var benchmarkReport: MotionBenchmarkReport?
    @Published private(set) var benchmarkHistory: [MotionBenchmarkReport] = []
    @Published private(set) var benchmarkRegression: MotionBenchmarkRegression?

    @Published private(set) var workspaceURL: URL = MotionStorage.defaultWorkspaceURL()
    @Published private(set) var persistenceStatus: String = "No workspace saved yet."

    @Published var autoAdaptEnabled = true {
        didSet {
            refreshQualityReport()
            queuePersistenceWrite()
        }
    }

    private var sequenceTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var pendingPeaks = MotionPeaks()
    private var inFlightRun: InFlightRun?

    init() {
        loadWorkspace(initialLoad: true)
        ensureProfileLibraryIntegrity()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
    }

    var canBranch: Bool {
        phase == .idle
    }

    var isBranched: Bool {
        phase == .branched
    }

    var latestRun: MotionRunMetrics? {
        runHistory.first
    }

    var activeProfile: MotionProfile? {
        guard let id = activeProfileID else { return nil }
        return profiles.first { $0.id == id }
    }

    func triggerBranch(trigger: MotionTrigger = .button) {
        guard canBranch else { return }
        sequenceTask?.cancel()
        sequenceTask = nil
        phase = .gesturing

        withAnimation(.easeInOut(duration: 0.28)) {
            prepProgress = 1
            glowPulse = 1
            branchBias = 0
            branchEnergy = max(branchEnergy, 0.32)
            gestureVelocity = max(gestureVelocity, 0.28)
        }

        pendingPeaks.ingest(prep: prepProgress, velocity: gestureVelocity, bias: branchBias)
        runSequence(preSplitDelay: tuning.preSplitDelay, trigger: trigger)
    }

    func updateGesture(value: DragGesture.Value) {
        guard phase == .idle || phase == .gesturing else { return }
        sequenceTask?.cancel()
        sequenceTask = nil

        phase = .gesturing

        let output = GestureSignalEstimator.estimate(
            input: GestureSignalInput(
                translation: value.translation,
                predictedEndTranslation: value.predictedEndTranslation,
                tuning: tuning
            )
        )

        prepProgress = output.prepProgress
        glowPulse = output.glowPulse
        gestureVelocity = output.velocity
        branchBias = output.bias
        branchEnergy = output.energy
        pendingPeaks.ingest(prep: output.prepProgress, velocity: output.velocity, bias: output.bias)
    }

    func endGesture() {
        guard phase == .gesturing else { return }

        if prepProgress >= tuning.gestureThreshold {
            withAnimation(.easeOut(duration: 0.14)) {
                prepProgress = 1
                glowPulse = 1
            }
            pendingPeaks.ingest(prep: prepProgress, velocity: gestureVelocity, bias: branchBias)
            runSequence(preSplitDelay: tuning.gestureCommitDelay, trigger: .gesture)
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            prepProgress = 0
            glowPulse = 0
            gestureVelocity = 0
            branchBias = 0
            branchEnergy = 0
        }
        pendingPeaks.reset()
        phase = .idle
    }

    func selectPreset(_ preset: MotionPreset) {
        selectedPreset = preset
        queuePersistenceWrite()
    }

    func applySelectedPreset() {
        applyPreset(selectedPreset)
    }

    func updateTuning(_ candidate: MotionTuning) {
        tuning = candidate.normalized()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func applyPreset(_ preset: MotionPreset) {
        selectedPreset = preset
        tuning = preset.tuning.normalized()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func setAutoAdapt(_ enabled: Bool) {
        autoAdaptEnabled = enabled
    }

    func selectActiveProfile(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        activeProfileID = profile.id
        tuning = profile.tuning.normalized()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func createProfileFromCurrent() {
        let now = Date()
        let profile = MotionProfile(
            id: UUID(),
            name: "Profile \(profiles.count + 1)",
            notes: "Created from current tuning.",
            tuning: tuning.normalized(),
            baseline: benchmarkReport.map(MotionBenchmarkBaseline.init(report:)),
            createdAt: now,
            updatedAt: now
        )
        profiles.insert(profile, at: 0)
        activeProfileID = profile.id
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func duplicateActiveProfile() {
        guard let active = activeProfile else { return }
        let now = Date()
        let profile = MotionProfile(
            id: UUID(),
            name: "\(active.name) Copy",
            notes: active.notes,
            tuning: active.tuning,
            baseline: active.baseline,
            createdAt: now,
            updatedAt: now
        )
        profiles.insert(profile, at: 0)
        activeProfileID = profile.id
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func deleteActiveProfile() {
        guard let activeID = activeProfileID else { return }
        guard profiles.count > 1 else {
            persistenceStatus = "At least one profile must exist."
            return
        }
        profiles.removeAll { $0.id == activeID }
        activeProfileID = profiles.first?.id
        if let profile = activeProfile {
            tuning = profile.tuning.normalized()
        }
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func saveCurrentToActiveProfile() {
        guard let activeID = activeProfileID, let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[index].tuning = tuning.normalized()
        profiles[index].updatedAt = Date()
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
    }

    func revertFromActiveProfile() {
        guard let profile = activeProfile else { return }
        tuning = profile.tuning.normalized()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
    }

    func setBaselineFromCurrentBenchmark() {
        guard let report = benchmarkReport else { return }
        guard let activeID = activeProfileID, let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[index].baseline = MotionBenchmarkBaseline(report: report)
        profiles[index].updatedAt = Date()
        evaluateBenchmarkRegression()
        queuePersistenceWrite()
    }

    func clearBaselineForActiveProfile() {
        guard let activeID = activeProfileID, let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[index].baseline = nil
        profiles[index].updatedAt = Date()
        evaluateBenchmarkRegression()
        queuePersistenceWrite()
    }

    func clearRunHistory() {
        runHistory.removeAll()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        queuePersistenceWrite()
    }

    func clearBenchmarkHistory() {
        benchmarkHistory.removeAll()
        queuePersistenceWrite()
    }

    func runBenchmarkSuite(recordHistory: Bool = true) {
        let report = MotionBenchmarkEngine.runSuite(tuning: tuning)
        benchmarkReport = report
        if recordHistory {
            benchmarkHistory.insert(report, at: 0)
            if benchmarkHistory.count > 24 {
                benchmarkHistory.removeLast(benchmarkHistory.count - 24)
            }
        }
        evaluateBenchmarkRegression()
        if recordHistory {
            queuePersistenceWrite()
        }
    }

    func saveWorkspaceNow() {
        persistenceTask?.cancel()
        do {
            let snapshot = makeWorkspaceSnapshot()
            _ = try MotionStorage.save(snapshot: snapshot, to: workspaceURL)
            persistenceStatus = "Saved \(Self.timeFormatter.string(from: Date()))"
        } catch {
            persistenceStatus = "Save failed: \(error.localizedDescription)"
        }
    }

    func reloadWorkspace() {
        loadWorkspace(initialLoad: false)
        ensureProfileLibraryIntegrity()
        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
    }

    func exportWorkspaceToDesktop() {
        do {
            let snapshot = makeWorkspaceSnapshot()
            let exportURL = MotionStorage.desktopExportURL()
            _ = try MotionStorage.save(snapshot: snapshot, to: exportURL)
            persistenceStatus = "Exported \(exportURL.lastPathComponent)"
        } catch {
            persistenceStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    func reset() {
        sequenceTask?.cancel()
        sequenceTask = nil
        inFlightRun = nil
        pendingPeaks.reset()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            prepProgress = 0
            splitProgress = 0
            settleProgress = 0
            glowPulse = 0
            showsChildren = false
            gestureVelocity = 0
            branchBias = 0
            branchEnergy = 0
        }

        phase = .idle
    }

    private func runSequence(preSplitDelay: Double, trigger: MotionTrigger) {
        sequenceTask?.cancel()
        let tuningSnapshot = tuning
        let springs = Self.dynamicSprings(
            tuning: tuningSnapshot,
            peakVelocity: pendingPeaks.velocity,
            prepPeak: pendingPeaks.prep
        )
        startRun(trigger: trigger)

        sequenceTask = Task {
            await Self.pause(seconds: preSplitDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .splitting
                showsChildren = true
                markSplitPhase()
                withAnimation(.easeOut(duration: 0.2)) {
                    branchEnergy = max(branchEnergy, 0.28)
                }
                withAnimation(
                    .interpolatingSpring(
                        stiffness: springs.splitStiffness,
                        damping: springs.splitDamping
                    )
                ) {
                    splitProgress = 1
                }
            }

            await Self.pause(seconds: tuningSnapshot.preSettleDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .settling
                markSettlePhase()
                withAnimation(
                    .interpolatingSpring(
                        stiffness: springs.settleStiffness,
                        damping: springs.settleDamping
                    )
                ) {
                    settleProgress = 1
                    glowPulse = 0
                }
                withAnimation(.easeOut(duration: max(0.2, tuningSnapshot.postSettleDelay))) {
                    branchEnergy *= 0.55
                    branchBias *= 0.65
                    gestureVelocity *= 0.35
                }
            }

            await Self.pause(seconds: tuningSnapshot.postSettleDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .branched
                withAnimation(.easeOut(duration: 0.25)) {
                    branchEnergy = 0
                    branchBias = 0
                    gestureVelocity = 0
                }
                finalizeRun()
            }
        }
    }

    private func startRun(trigger: MotionTrigger) {
        inFlightRun = InFlightRun(
            trigger: trigger,
            startedAt: Date(),
            prepPeak: pendingPeaks.prep,
            velocityPeak: pendingPeaks.velocity,
            biasPeak: pendingPeaks.bias
        )
    }

    private func markSplitPhase() {
        mutateRun { run in
            run.splitAt = Date()
            run.prepPeak = max(run.prepPeak, prepProgress)
            run.velocityPeak = max(run.velocityPeak, gestureVelocity)
            run.biasPeak = maxByMagnitude(lhs: run.biasPeak, rhs: branchBias)
        }
    }

    private func markSettlePhase() {
        mutateRun { run in
            run.settleAt = Date()
            run.velocityPeak = max(run.velocityPeak, gestureVelocity)
            run.biasPeak = maxByMagnitude(lhs: run.biasPeak, rhs: branchBias)
        }
    }

    private func finalizeRun() {
        guard let run = inFlightRun else { return }

        let end = Date()
        let splitAt = run.splitAt ?? end
        let settleAt = run.settleAt ?? splitAt

        let metrics = MotionRunMetrics(
            timestamp: end,
            trigger: run.trigger,
            prepPeak: run.prepPeak,
            velocityPeak: run.velocityPeak,
            biasPeak: run.biasPeak,
            phases: MotionPhaseDurations(
                preSplit: max(0, splitAt.timeIntervalSince(run.startedAt)),
                preSettle: max(0, settleAt.timeIntervalSince(splitAt)),
                settleTail: max(0, end.timeIntervalSince(settleAt))
            )
        )

        runHistory.insert(metrics, at: 0)
        if runHistory.count > 40 {
            runHistory.removeLast(runHistory.count - 40)
        }

        if autoAdaptEnabled {
            tuning = MotionAdaptiveEngine.adapt(tuning: tuning, basedOn: metrics)
        }

        refreshQualityReport()
        runBenchmarkSuite(recordHistory: false)
        refreshProfileDirtyFlag()
        queuePersistenceWrite()
        inFlightRun = nil
        pendingPeaks.reset()
    }

    private func refreshQualityReport() {
        qualityReport = MotionQualityEvaluator.evaluate(tuning: tuning, recentRuns: runHistory)
    }

    private func evaluateBenchmarkRegression() {
        guard let report = benchmarkReport, let baseline = activeProfile?.baseline else {
            benchmarkRegression = nil
            return
        }
        benchmarkRegression = MotionBenchmarkRegressionEvaluator.compare(report: report, baseline: baseline)
    }

    private func refreshProfileDirtyFlag() {
        guard let profile = activeProfile else {
            profileIsDirty = false
            return
        }
        profileIsDirty = profile.tuning.normalized() != tuning.normalized()
    }

    private func ensureProfileLibraryIntegrity() {
        if profiles.isEmpty {
            let now = Date()
            let profile = MotionProfile(
                id: UUID(),
                name: "Default",
                notes: "Auto-generated profile.",
                tuning: tuning.normalized(),
                baseline: nil,
                createdAt: now,
                updatedAt: now
            )
            profiles = [profile]
            activeProfileID = profile.id
            profileIsDirty = false
            return
        }

        if let activeID = activeProfileID, profiles.contains(where: { $0.id == activeID }) {
            refreshProfileDirtyFlag()
        } else {
            activeProfileID = profiles.first?.id
            refreshProfileDirtyFlag()
        }
    }

    private func makeWorkspaceSnapshot() -> MotionWorkspaceSnapshot {
        MotionWorkspaceSnapshot(
            selectedPresetRawValue: selectedPreset.rawValue,
            autoAdaptEnabled: autoAdaptEnabled,
            tuning: MotionTuningRecord(tuning: tuning),
            runHistory: runHistory.map(MotionRunRecord.init(metrics:)),
            profiles: profiles.map(MotionProfileRecord.init(profile:)),
            activeProfileID: activeProfileID?.uuidString,
            benchmarkHistory: benchmarkHistory.map(MotionBenchmarkRecord.init(report:)),
            latestBenchmark: benchmarkReport.map(MotionBenchmarkRecord.init(report:)),
            savedAt: Date()
        )
    }

    private func applyWorkspaceSnapshot(_ snapshot: MotionWorkspaceSnapshot) {
        selectedPreset = MotionPreset(rawValue: snapshot.selectedPresetRawValue) ?? .balanced
        autoAdaptEnabled = snapshot.autoAdaptEnabled
        tuning = snapshot.tuning.tuning.normalized()
        runHistory = snapshot.runHistory.map(\.metrics)
            .sorted(by: { $0.timestamp > $1.timestamp })
        if runHistory.count > 40 {
            runHistory.removeLast(runHistory.count - 40)
        }

        profiles = snapshot.profiles.map(\.profile)
            .sorted(by: { $0.updatedAt > $1.updatedAt })
        activeProfileID = snapshot.activeProfileID.flatMap(UUID.init(uuidString:))

        benchmarkHistory = snapshot.benchmarkHistory.map(\.report)
            .sorted(by: { $0.generatedAt > $1.generatedAt })
        benchmarkReport = snapshot.latestBenchmark?.report ?? benchmarkHistory.first

        persistenceStatus = "Loaded \(Self.timeFormatter.string(from: snapshot.savedAt))"
    }

    private func loadWorkspace(initialLoad: Bool) {
        do {
            let snapshot = try MotionStorage.load(from: workspaceURL)
            applyWorkspaceSnapshot(snapshot)
        } catch MotionStorageError.snapshotNotFound {
            if initialLoad {
                persistenceStatus = "No saved workspace found at \(workspaceURL.path)"
                queuePersistenceWrite()
            } else {
                persistenceStatus = "Workspace file not found."
            }
        } catch {
            persistenceStatus = "Load failed: \(error.localizedDescription)"
        }
    }

    private func queuePersistenceWrite() {
        persistenceTask?.cancel()
        let snapshot = makeWorkspaceSnapshot()
        let targetURL = workspaceURL
        persistenceTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 360_000_000)
            _ = try? MotionStorage.save(snapshot: snapshot, to: targetURL)
        }
    }

    private func mutateRun(_ body: (inout InFlightRun) -> Void) {
        guard var run = inFlightRun else { return }
        body(&run)
        inFlightRun = run
    }

    private func maxByMagnitude(lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        abs(rhs) > abs(lhs) ? rhs : lhs
    }

    private static func dynamicSprings(
        tuning: MotionTuning,
        peakVelocity: CGFloat,
        prepPeak: CGFloat
    ) -> MotionSprings {
        let velocity = Double(max(0, min(1, peakVelocity)))
        let prep = Double(max(0, min(1, prepPeak)))

        let splitStiffness = clamp(
            tuning.splitStiffness * (1 + (0.16 * velocity)),
            to: MotionTuning.splitStiffnessRange
        )
        let splitDamping = clamp(
            tuning.splitDamping * (1 + (0.24 * velocity)),
            to: MotionTuning.splitDampingRange
        )
        let settleStiffness = clamp(
            tuning.settleStiffness * (1 + (0.08 * prep)),
            to: MotionTuning.settleStiffnessRange
        )
        let settleDamping = clamp(
            tuning.settleDamping * (1 + (0.32 * velocity)),
            to: MotionTuning.settleDampingRange
        )

        return MotionSprings(
            splitStiffness: splitStiffness,
            splitDamping: splitDamping,
            settleStiffness: settleStiffness,
            settleDamping: settleDamping
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, value))
    }

    private static func pause(seconds: Double) async {
        let clamped = max(0, seconds)
        let nanos = UInt64(clamped * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    deinit {
        sequenceTask?.cancel()
        persistenceTask?.cancel()
    }
}

private struct MotionPeaks {
    var prep: CGFloat = 0
    var velocity: CGFloat = 0
    var bias: CGFloat = 0

    mutating func ingest(prep: CGFloat, velocity: CGFloat, bias: CGFloat) {
        self.prep = max(self.prep, prep)
        self.velocity = max(self.velocity, velocity)
        self.bias = abs(bias) > abs(self.bias) ? bias : self.bias
    }

    mutating func reset() {
        prep = 0
        velocity = 0
        bias = 0
    }
}

private struct InFlightRun {
    let trigger: MotionTrigger
    let startedAt: Date
    var splitAt: Date?
    var settleAt: Date?
    var prepPeak: CGFloat
    var velocityPeak: CGFloat
    var biasPeak: CGFloat
}

private struct MotionSprings {
    let splitStiffness: Double
    let splitDamping: Double
    let settleStiffness: Double
    let settleDamping: Double
}
