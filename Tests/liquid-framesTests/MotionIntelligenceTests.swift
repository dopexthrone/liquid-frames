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

    let profile = sampleProfile(name: "Cinematic RC")
    let snapshot = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.cinematic.rawValue,
        autoAdaptEnabled: false,
        tuning: MotionTuningRecord(tuning: MotionPreset.cinematic.tuning),
        runHistory: [MotionRunRecord(metrics: sampleRun(duration: 1.41))],
        profiles: [MotionProfileRecord(profile: profile)],
        activeProfileID: profile.id.uuidString,
        benchmarkHistory: [MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 87))],
        latestBenchmark: MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 87)),
        savedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    _ = try MotionStorage.save(snapshot: snapshot, to: tempURL)
    let loaded = try MotionStorage.load(from: tempURL)

    #expect(loaded.selectedPresetRawValue == snapshot.selectedPresetRawValue)
    #expect(loaded.autoAdaptEnabled == snapshot.autoAdaptEnabled)
    #expect(loaded.tuning == snapshot.tuning)
    #expect(loaded.runHistory.count == 1)
    #expect(loaded.runHistory.first?.triggerRawValue == MotionTrigger.button.rawValue)
    #expect(loaded.profiles.count == 1)
    #expect(loaded.latestBenchmark?.gradeRawValue == MotionBenchmarkGrade.b.rawValue)
}

@Test
func benchmarkRegressionEvaluatorFlagsFailures() {
    let baseline = MotionBenchmarkBaseline(report: sampleBenchmarkReport(score: 92))
    let regressed = sampleBenchmarkReport(
        score: 80,
        consistency: 70,
        scenarioOverrides: [
            "Gentle Gesture": 78,
            "Assertive Gesture": 71,
            "Lateral Bias Gesture": 60,
            "Button Trigger": 73
        ]
    )

    let regression = MotionBenchmarkRegressionEvaluator.compare(report: regressed, baseline: baseline)

    #expect(regression.status == .fail)
    #expect(regression.overallDelta < 0)
    #expect(regression.worstScenarioDelta < -10)
}

@Test
func legacySnapshotDecodeUsesDefaultsForNewFields() throws {
    let legacyJSON = """
    {
      "schemaVersion": 1,
      "selectedPresetRawValue": "balanced",
      "autoAdaptEnabled": true,
      "tuning": {
        "splitStiffness": 180,
        "splitDamping": 22,
        "settleStiffness": 145,
        "settleDamping": 14,
        "preSplitDelay": 0.32,
        "gestureCommitDelay": 0.10,
        "preSettleDelay": 0.56,
        "postSettleDelay": 0.42,
        "gestureThreshold": 0.62,
        "pullDistance": 210,
        "velocityScale": 160,
        "velocityInfluence": 0.72,
        "biasInfluence": 0.45
      },
      "runHistory": [],
      "savedAt": "2023-11-14T22:13:20Z"
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let snapshot = try decoder.decode(MotionWorkspaceSnapshot.self, from: Data(legacyJSON.utf8))

    #expect(snapshot.selectedPresetRawValue == MotionPreset.balanced.rawValue)
    #expect(snapshot.profiles.isEmpty)
    #expect(snapshot.activeProfileID == nil)
    #expect(snapshot.benchmarkHistory.isEmpty)
    #expect(snapshot.latestBenchmark == nil)
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

private func sampleProfile(name: String) -> MotionProfile {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    return MotionProfile(
        id: UUID(),
        name: name,
        notes: "test",
        tuning: MotionPreset.cinematic.tuning,
        baseline: MotionBenchmarkBaseline(report: sampleBenchmarkReport(score: 86)),
        createdAt: now,
        updatedAt: now
    )
}

private func sampleBenchmarkReport(
    score: Double,
    consistency: Double = 82,
    scenarioOverrides: [String: Double] = [:]
) -> MotionBenchmarkReport {
    let baseScores: [String: Double] = [
        "Gentle Gesture": 88,
        "Assertive Gesture": 84,
        "Lateral Bias Gesture": 83,
        "Button Trigger": 86
    ]

    let scenarios = baseScores.map { key, baseValue in
        MotionBenchmarkScenarioResult(
            scenarioName: key,
            trigger: key == "Button Trigger" ? .button : .gesture,
            estimatedDuration: 1.34,
            responsiveness: 0.82,
            stability: 0.8,
            score: scenarioOverrides[key] ?? baseValue
        )
    }

    let grade: MotionBenchmarkGrade
    switch score {
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
        generatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        overallScore: score,
        consistencyScore: consistency,
        grade: grade,
        scenarios: scenarios,
        quality: MotionQualityReport(level: .healthy, messages: ["ok"])
    )
}
