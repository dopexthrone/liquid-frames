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

enum MotionPreset: String, CaseIterable, Identifiable {
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

enum MotionTrigger: String {
    case gesture
    case button
    case replay
}

struct MotionPhaseDurations: Equatable {
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

enum MotionQualityLevel: String {
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
