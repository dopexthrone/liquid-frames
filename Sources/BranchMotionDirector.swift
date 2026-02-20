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
        phase = .gesturing

        withAnimation(.easeInOut(duration: 0.28)) {
            prepProgress = 1
            glowPulse = 1
        }

        sequenceTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .splitting
                showsChildren = true
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 22)) {
                    splitProgress = 1
                }
            }

            try? await Task.sleep(nanoseconds: 560_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .settling
                withAnimation(.interpolatingSpring(stiffness: 145, damping: 14)) {
                    settleProgress = 1
                    glowPulse = 0
                }
            }

            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                phase = .branched
            }
        }
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

    deinit {
        sequenceTask?.cancel()
    }
}
