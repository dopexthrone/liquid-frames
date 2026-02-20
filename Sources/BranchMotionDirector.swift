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
}

@MainActor
final class BranchMotionDirector: ObservableObject {
    @Published private(set) var phase: BranchPhase = .idle
    @Published private(set) var prepProgress: CGFloat = 0
    @Published private(set) var splitProgress: CGFloat = 0
    @Published private(set) var settleProgress: CGFloat = 0
    @Published private(set) var glowPulse: CGFloat = 0
    @Published private(set) var showsChildren: Bool = false
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
        }

        runSequence(preSplitDelay: tuning.preSplitDelay)
    }

    func updateGesture(translation: CGSize) {
        guard phase == .idle || phase == .gesturing else { return }
        sequenceTask?.cancel()
        sequenceTask = nil

        phase = .gesturing

        let pull = max(0, -translation.height) + (abs(translation.width) * 0.25)
        let normalized = min(1, pull / max(120, tuning.pullDistance))

        prepProgress = normalized
        glowPulse = min(1, normalized * 1.15)
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
            }

            await Self.pause(seconds: tuningSnapshot.postSettleDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .branched
            }
        }
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
