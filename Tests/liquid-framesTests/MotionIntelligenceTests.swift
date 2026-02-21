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

@Test
func profileRecordDecodeDefaultsTagsAndNormalizesMetadata() throws {
    let rawJSON = """
    {
      "id": "123E4567-E89B-12D3-A456-426614174000",
      "name": "  Imported Profile  ",
      "notes": "  Notes  ",
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
      "createdAt": "2023-11-14T22:13:20Z",
      "updatedAt": "2023-11-14T22:14:20Z"
    }
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let record = try decoder.decode(MotionProfileRecord.self, from: Data(rawJSON.utf8))

    #expect(record.tags.isEmpty)
    #expect(record.profile.name == "Imported Profile")
    #expect(record.profile.notes == "Notes")
}

@Test
func workspaceMergePrefersNewestProfileMetadataAndDedupesRuns() {
    let sharedID = UUID()
    let incomingOnlyID = UUID()
    let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

    let currentShared = MotionProfile(
        id: sharedID,
        name: "Current",
        notes: "baseline",
        tags: ["current"],
        tuning: MotionPreset.balanced.tuning,
        baseline: nil,
        createdAt: baseTime,
        updatedAt: baseTime
    )
    let incomingShared = MotionProfile(
        id: sharedID,
        name: "Incoming Updated",
        notes: "refined",
        tags: ["incoming", "Incoming"],
        tuning: MotionPreset.responsive.tuning,
        baseline: nil,
        createdAt: baseTime,
        updatedAt: baseTime.addingTimeInterval(120)
    )
    let incomingOnly = MotionProfile(
        id: incomingOnlyID,
        name: "Incoming Only",
        notes: "new",
        tags: ["demo"],
        tuning: MotionPreset.cinematic.tuning,
        baseline: nil,
        createdAt: baseTime.addingTimeInterval(10),
        updatedAt: baseTime.addingTimeInterval(140)
    )

    let sharedRunTimestamp = baseTime.addingTimeInterval(60)
    let duplicateRun = MotionRunRecord(
        metrics: sampleRun(duration: 1.34, timestamp: sharedRunTimestamp)
    )
    let uniqueIncomingRun = MotionRunRecord(
        metrics: sampleRun(duration: 1.52, timestamp: baseTime.addingTimeInterval(90))
    )

    let current = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.balanced.rawValue,
        autoAdaptEnabled: true,
        tuning: MotionTuningRecord(tuning: MotionPreset.balanced.tuning),
        runHistory: [duplicateRun],
        profiles: [MotionProfileRecord(profile: currentShared)],
        activeProfileID: currentShared.id.uuidString,
        benchmarkHistory: [MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 82))],
        latestBenchmark: nil,
        savedAt: baseTime
    )

    let incoming = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.cinematic.rawValue,
        autoAdaptEnabled: false,
        tuning: MotionTuningRecord(tuning: MotionPreset.cinematic.tuning),
        runHistory: [duplicateRun, uniqueIncomingRun],
        profiles: [
            MotionProfileRecord(profile: incomingShared),
            MotionProfileRecord(profile: incomingOnly)
        ],
        activeProfileID: incomingOnly.id.uuidString,
        benchmarkHistory: [MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 91))],
        latestBenchmark: MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 91)),
        savedAt: baseTime.addingTimeInterval(200)
    )

    let merged = MotionWorkspaceMerger.merge(current: current, incoming: incoming)

    #expect(merged.selectedPresetRawValue == MotionPreset.cinematic.rawValue)
    #expect(merged.autoAdaptEnabled == false)
    #expect(merged.profiles.count == 2)
    #expect(merged.activeProfileID == incomingOnly.id.uuidString)
    #expect(merged.runHistory.count == 2)

    let mergedShared = merged.profiles.first(where: { $0.id == sharedID.uuidString })
    #expect(mergedShared?.name == "Incoming Updated")
    #expect(mergedShared?.tags == ["incoming"])
}

@Test
func workspaceMergeRetainsCurrentActiveProfileWhenIncomingActiveIsMissing() {
    let sharedID = UUID()
    let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

    let profile = MotionProfile(
        id: sharedID,
        name: "Current",
        notes: "baseline",
        tags: ["current"],
        tuning: MotionPreset.balanced.tuning,
        baseline: nil,
        createdAt: baseTime,
        updatedAt: baseTime
    )

    let current = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.balanced.rawValue,
        autoAdaptEnabled: true,
        tuning: MotionTuningRecord(tuning: MotionPreset.balanced.tuning),
        runHistory: [],
        profiles: [MotionProfileRecord(profile: profile)],
        activeProfileID: sharedID.uuidString,
        benchmarkHistory: [],
        latestBenchmark: nil,
        savedAt: baseTime
    )

    let incoming = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.cinematic.rawValue,
        autoAdaptEnabled: false,
        tuning: MotionTuningRecord(tuning: MotionPreset.cinematic.tuning),
        runHistory: [],
        profiles: [MotionProfileRecord(profile: profile)],
        activeProfileID: nil,
        benchmarkHistory: [],
        latestBenchmark: nil,
        savedAt: baseTime.addingTimeInterval(30)
    )

    let merged = MotionWorkspaceMerger.merge(current: current, incoming: incoming)

    #expect(merged.activeProfileID == sharedID.uuidString)
}

@Test
func releaseGateReportMarksBlockedWhenRegressionFails() {
    let profile = sampleProfile(name: "Release Candidate")
    let benchmark = sampleBenchmarkReport(score: 91, consistency: 88)
    let regression = MotionBenchmarkRegression(
        status: .fail,
        overallDelta: -8,
        consistencyDelta: -9,
        worstScenarioDelta: -14,
        messages: ["Regression failed."]
    )

    let report = MotionReleaseGateReport(
        generatedAt: Date(timeIntervalSince1970: 1_700_000_500),
        workspacePath: "/tmp/workspace.json",
        profile: profile,
        profileIsDirty: false,
        quality: MotionQualityReport(level: .healthy, messages: ["stable"]),
        benchmark: benchmark,
        regression: regression,
        latestRun: sampleRun(duration: 1.31),
        runCount: 8,
        benchmarkHistoryCount: 4
    )

    #expect(report.status == .blocked)
    #expect(report.markdown.contains("**BLOCKED**"))
    #expect(report.markdown.contains("Release Candidate"))
    #expect(report.findings.contains(where: { $0.contains("FAIL") }))
}

@Test
func birthDynamicsEngineTightensNeckDuringSplitThenSettles() {
    let early = BirthDynamicsEngine.sample(
        prepProgress: 0.4,
        splitProgress: 0.2,
        settleProgress: 0,
        velocity: 0.32,
        energy: 0.42,
        bias: 0.1
    )
    let peak = BirthDynamicsEngine.sample(
        prepProgress: 1,
        splitProgress: 0.86,
        settleProgress: 0.18,
        velocity: 0.72,
        energy: 0.82,
        bias: 0.24
    )
    let settled = BirthDynamicsEngine.sample(
        prepProgress: 1,
        splitProgress: 1,
        settleProgress: 1,
        velocity: 0.1,
        energy: 0.08,
        bias: 0
    )

    #expect(peak.neckConstriction > early.neckConstriction)
    #expect(settled.neckConstriction < peak.neckConstriction)
    #expect(settled.fluidTransfer < peak.fluidTransfer)
    #expect(abs(settled.pulse) < abs(peak.pulse))
}

@Test
func birthDynamicsEngineBreathesThenSpits() {
    let inhaleState = BirthDynamicsEngine.sample(
        prepProgress: 0.82,
        splitProgress: 0.04,
        settleProgress: 0,
        velocity: 0.2,
        energy: 0.3,
        bias: 0
    )

    let spitState = BirthDynamicsEngine.sample(
        prepProgress: 1,
        splitProgress: 0.76,
        settleProgress: 0.12,
        velocity: 0.64,
        energy: 0.76,
        bias: 0
    )

    #expect(inhaleState.inhale > inhaleState.exhale)
    #expect(spitState.exhale > spitState.inhale)
    #expect(spitState.aperture > inhaleState.aperture)
    #expect(spitState.spitStrength > inhaleState.spitStrength)
}

@Test
func birthDynamicsEngineApertureContractsAfterSettle() {
    let active = BirthDynamicsEngine.sample(
        prepProgress: 1,
        splitProgress: 0.72,
        settleProgress: 0.14,
        velocity: 0.58,
        energy: 0.62,
        bias: 0
    )
    let settled = BirthDynamicsEngine.sample(
        prepProgress: 1,
        splitProgress: 1,
        settleProgress: 1,
        velocity: 0.1,
        energy: 0.1,
        bias: 0
    )

    #expect(active.aperture > settled.aperture)
    #expect(active.spitStrength > settled.spitStrength)
}

@Test
func birthDynamicsEngineIsDeterministic() {
    let a = BirthDynamicsEngine.sample(
        prepProgress: 0.88,
        splitProgress: 0.63,
        settleProgress: 0.27,
        velocity: 0.55,
        energy: 0.74,
        bias: -0.33
    )
    let b = BirthDynamicsEngine.sample(
        prepProgress: 0.88,
        splitProgress: 0.63,
        settleProgress: 0.27,
        velocity: 0.55,
        energy: 0.74,
        bias: -0.33
    )

    #expect(a == b)
}

@Test
func spawnCascadePhaserStaggersLeftBeforeRight() {
    let phases = SpawnCascadePhaser.sample(progress: 0.36, leftLeafCount: 2, rightLeafCount: 2)

    #expect(phases.leftBranch > phases.rightBranch)
    #expect(phases.leftLeaves.first ?? 0 > 0)
    #expect(phases.rightLeaves.first ?? 0 < phases.leftLeaves.first ?? 0)
}

@Test
func spawnCascadePhaserCompletesAllStagesAtFullProgress() {
    let phases = SpawnCascadePhaser.sample(progress: 1, leftLeafCount: 2, rightLeafCount: 2)

    #expect(phases.leftBranch == 1)
    #expect(phases.rightBranch == 1)
    #expect(phases.leftLeaves.allSatisfy { $0 == 1 })
    #expect(phases.rightLeaves.allSatisfy { $0 == 1 })
    #expect(phases.chainCoverage == 1)
}

@Test
func spawnCascadePhaserIsDeterministic() {
    let a = SpawnCascadePhaser.sample(progress: 0.57, leftLeafCount: 3, rightLeafCount: 2)
    let b = SpawnCascadePhaser.sample(progress: 0.57, leftLeafCount: 3, rightLeafCount: 2)

    #expect(a == b)
}

@Test
func agentCheckReturnsFailureForMissingWorkspace() {
    let workspacePath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json", isDirectory: false)
        .path

    let exitCode = AgentCommandLine.runIfRequested(
        arguments: [
            "liquid-frames",
            "--agent",
            "check",
            "--workspace", workspacePath
        ],
        emitOutput: false
    )

    #expect(exitCode == 2)
}

@Test
func agentCheckPassesForValidWorkspaceWithRelaxedGate() throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("liquid-frames-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString + ".json", isDirectory: false)
    let profile = sampleProfile(name: "Agent Ready")
    let snapshot = MotionWorkspaceSnapshot(
        selectedPresetRawValue: MotionPreset.responsive.rawValue,
        autoAdaptEnabled: false,
        tuning: MotionTuningRecord(tuning: profile.tuning),
        runHistory: [
            MotionRunRecord(metrics: sampleRun(duration: 1.26)),
            MotionRunRecord(metrics: sampleRun(duration: 1.31))
        ],
        profiles: [MotionProfileRecord(profile: profile)],
        activeProfileID: profile.id.uuidString,
        benchmarkHistory: [MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 86))],
        latestBenchmark: MotionBenchmarkRecord(report: sampleBenchmarkReport(score: 86)),
        savedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    _ = try MotionStorage.save(snapshot: snapshot, to: tempURL)

    let exitCode = AgentCommandLine.runIfRequested(
        arguments: [
            "liquid-frames",
            "--agent",
            "check",
            "--workspace", tempURL.path,
            "--allow-attention",
            "--min-runs", "2"
        ],
        emitOutput: false
    )

    #expect(exitCode == 0)
}

@Test
func agentBenchmarkCommandReturnsSuccess() {
    let exitCode = AgentCommandLine.runIfRequested(
        arguments: [
            "liquid-frames",
            "--agent",
            "benchmark",
            "--preset", "responsive"
        ],
        emitOutput: false
    )

    #expect(exitCode == 0)
}

private func sampleRun(duration: Double, timestamp: Date = Date()) -> MotionRunMetrics {
    MotionRunMetrics(
        timestamp: timestamp,
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
        tags: ["test"],
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
