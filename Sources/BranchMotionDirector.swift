import SwiftUI

enum BranchPhase: String {
    case idle
    case gesturing
    case splitting
    case settling
    case branched
}

struct MotionTuning {
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
    @Published var tuning = MotionTuning()

    private var sequenceTask: Task<Void, Never>?

    var canBranch: Bool {
        phase == .idle
    }

    var isBranched: Bool {
        phase == .branched
    }

    func triggerBranch() {
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

        runSequence(preSplitDelay: tuning.preSplitDelay)
    }

    func updateGesture(value: DragGesture.Value) {
        guard phase == .idle || phase == .gesturing else { return }
        sequenceTask?.cancel()
        sequenceTask = nil

        phase = .gesturing

        let translation = value.translation
        let pull = max(0, -translation.height) + (abs(translation.width) * 0.25)
        let normalized = min(1, pull / max(120, tuning.pullDistance))

        let projectedDeltaX = value.predictedEndTranslation.width - translation.width
        let projectedDeltaY = value.predictedEndTranslation.height - translation.height
        let projectedDistance = hypot(projectedDeltaX, projectedDeltaY)
        let velocity = min(1, projectedDistance / max(80, tuning.velocityScale))

        let horizontalBias = translation.width / max(80, tuning.pullDistance * 0.8)
        let projectedBias = projectedDeltaX / max(100, tuning.pullDistance)
        let combinedBias = clamp(
            horizontalBias + (projectedBias * tuning.biasInfluence),
            min: -1,
            max: 1
        )
        let energy = min(1, (normalized * 0.35) + (velocity * tuning.velocityInfluence))

        prepProgress = normalized
        glowPulse = min(1, (normalized * 1.1) + (velocity * 0.2))
        gestureVelocity = velocity
        branchBias = combinedBias
        branchEnergy = energy
    }

    func endGesture() {
        guard phase == .gesturing else { return }

        if prepProgress >= tuning.gestureThreshold {
            withAnimation(.easeOut(duration: 0.14)) {
                prepProgress = 1
                glowPulse = 1
            }
            runSequence(preSplitDelay: tuning.gestureCommitDelay)
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            prepProgress = 0
            glowPulse = 0
            gestureVelocity = 0
            branchBias = 0
            branchEnergy = 0
        }
        phase = .idle
    }

    func reset() {
        sequenceTask?.cancel()
        sequenceTask = nil

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

    private func runSequence(preSplitDelay: Double) {
        sequenceTask?.cancel()
        let tuningSnapshot = tuning

        sequenceTask = Task {
            await Self.pause(seconds: preSplitDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .splitting
                showsChildren = true
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
            }
        }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
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
