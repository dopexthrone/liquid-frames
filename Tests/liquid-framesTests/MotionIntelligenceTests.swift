import CoreGraphics
import Foundation
import Testing
@testable import liquid_frames

@Test
func tuningNormalizationClampsValues() {
    let raw = MotionTuning(
        splitStiffness: 999,
        splitDamping: -8,
        settleStiffness: 999,
        settleDamping: -2,
        preSplitDelay: -1,
        gestureCommitDelay: 1,
        preSettleDelay: -2,
        postSettleDelay: 2,
        gestureThreshold: 9,
        pullDistance: -40,
        velocityScale: -1,
        velocityInfluence: 8,
        biasInfluence: -9
    )

    let normalized = raw.normalized()

    #expect(normalized.splitStiffness == MotionTuning.splitStiffnessRange.upperBound)
    #expect(normalized.splitDamping == MotionTuning.splitDampingRange.lowerBound)
    #expect(normalized.gestureThreshold == MotionTuning.gestureThresholdRange.upperBound)
    #expect(normalized.pullDistance == MotionTuning.pullDistanceRange.lowerBound)
    #expect(normalized.biasInfluence == MotionTuning.biasInfluenceRange.lowerBound)
}

@Test
func gestureSignalEstimatorIncreasesPrepWithMorePull() {
    let tuning = MotionPreset.balanced.tuning
    let low = GestureSignalEstimator.estimate(
        input: GestureSignalInput(
            translation: CGSize(width: 0, height: -40),
            predictedEndTranslation: CGSize(width: 0, height: -60),
            tuning: tuning
        )
    )
    let high = GestureSignalEstimator.estimate(
        input: GestureSignalInput(
            translation: CGSize(width: 0, height: -240),
            predictedEndTranslation: CGSize(width: 0, height: -340),
            tuning: tuning
        )
    )

    #expect(high.prepProgress > low.prepProgress)
    #expect(high.energy > low.energy)
}

@Test
func adaptiveEngineAcceleratesSlowRuns() {
    let base = MotionPreset.balanced.tuning
    let slowRun = MotionRunMetrics(
        timestamp: Date(),
        trigger: .gesture,
        prepPeak: 1,
        velocityPeak: 0.65,
        biasPeak: 0.12,
        phases: MotionPhaseDurations(preSplit: 0.54, preSettle: 1.05, settleTail: 0.68)
    )

    let adapted = MotionAdaptiveEngine.adapt(tuning: base, basedOn: slowRun)

    #expect(adapted.splitStiffness > base.splitStiffness)
    #expect(adapted.preSettleDelay < base.preSettleDelay)
    #expect(adapted.postSettleDelay < base.postSettleDelay)
}

@Test
func qualityEvaluatorFlagsUnstableRuns() {
    var tuning = MotionPreset.balanced.tuning
    tuning.velocityInfluence = 1.15
    tuning.gestureThreshold = 0.86
    let runs = [
        sampleRun(duration: 0.9),
        sampleRun(duration: 2.4),
        sampleRun(duration: 1.1),
        sampleRun(duration: 2.2)
    ]

    let report = MotionQualityEvaluator.evaluate(tuning: tuning, recentRuns: runs)

    #expect(report.level == .unstable)
    #expect(!report.messages.isEmpty)
}

@Test
func benchmarkSuiteIsDeterministicForSameTuning() {
    let tuning = MotionPreset.responsive.tuning
    let a = MotionBenchmarkEngine.runSuite(tuning: tuning)
    let b = MotionBenchmarkEngine.runSuite(tuning: tuning)

    #expect(a.grade == b.grade)
    #expect(abs(a.overallScore - b.overallScore) < 0.0001)
    #expect(abs(a.consistencyScore - b.consistencyScore) < 0.0001)
    #expect(a.scenarios.map(\.score) == b.scenarios.map(\.score))
}

@Test
func workspaceSnapshotRoundTripPersistsCoreState() throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("liquid-frames-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString + ".json", isDirectory: false)

    let snapshot = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.cinematic.rawValue,
        autoAdaptEnabled: false,
        tuning: MotionTuningRecord(tuning: MotionPreset.cinematic.tuning),
        runHistory: [MotionRunRecord(metrics: sampleRun(duration: 1.41))],
        savedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    _ = try MotionStorage.save(snapshot: snapshot, to: tempURL)
    let loaded = try MotionStorage.load(from: tempURL)

    #expect(loaded.selectedPresetRawValue == snapshot.selectedPresetRawValue)
    #expect(loaded.autoAdaptEnabled == snapshot.autoAdaptEnabled)
    #expect(loaded.tuning == snapshot.tuning)
    #expect(loaded.runHistory.count == 1)
    #expect(loaded.runHistory.first?.triggerRawValue == MotionTrigger.button.rawValue)
}

private func sampleRun(duration: Double) -> MotionRunMetrics {
    MotionRunMetrics(
        timestamp: Date(),
        trigger: .button,
        prepPeak: 1,
        velocityPeak: 0.4,
        biasPeak: 0,
        phases: MotionPhaseDurations(
            preSplit: duration * 0.28,
            preSettle: duration * 0.44,
            settleTail: duration * 0.28
        )
    )
}
