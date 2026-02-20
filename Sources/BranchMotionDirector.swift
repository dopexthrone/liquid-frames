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
    @Published private(set) var tuning: MotionTuning = MotionPreset.balanced.tuning
    @Published private(set) var runHistory: [MotionRunMetrics] = []
    @Published private(set) var qualityReport = MotionQualityReport(
        level: .healthy,
        messages: ["Motion profile is within target reliability bounds."]
    )
    @Published var autoAdaptEnabled = true {
        didSet { refreshQualityReport() }
    }

    private var sequenceTask: Task<Void, Never>?
    private var pendingPeaks = MotionPeaks()
    private var inFlightRun: InFlightRun?

    var canBranch: Bool {
        phase == .idle
    }

    var isBranched: Bool {
        phase == .branched
    }

    var latestRun: MotionRunMetrics? {
        runHistory.first
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

    func updateTuning(_ candidate: MotionTuning) {
        tuning = candidate.normalized()
        refreshQualityReport()
    }

    func applyPreset(_ preset: MotionPreset) {
        updateTuning(preset.tuning)
    }

    func setAutoAdapt(_ enabled: Bool) {
        autoAdaptEnabled = enabled
    }

    func clearRunHistory() {
        runHistory.removeAll()
        refreshQualityReport()
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
                        stiffness: tuningSnapshot.splitStiffness,
                        damping: tuningSnapshot.splitDamping
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
                        stiffness: tuningSnapshot.settleStiffness,
                        damping: tuningSnapshot.settleDamping
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
        inFlightRun = nil
        pendingPeaks.reset()
    }

    private func refreshQualityReport() {
        qualityReport = MotionQualityEvaluator.evaluate(tuning: tuning, recentRuns: runHistory)
    }

    private func mutateRun(_ body: (inout InFlightRun) -> Void) {
        guard var run = inFlightRun else { return }
        body(&run)
        inFlightRun = run
    }

    private func maxByMagnitude(lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        abs(rhs) > abs(lhs) ? rhs : lhs
    }

    private static func pause(seconds: Double) async {
        let clamped = max(0, seconds)
        let nanos = UInt64(clamped * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
    }

    deinit {
        sequenceTask?.cancel()
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
