import SwiftUI

struct PrototypeRootView: View {
    @StateObject private var motion = BranchMotionDirector()
    @State private var showsTuning = true

    var body: some View {
        GeometryReader { proxy in
            let birthDynamics = BirthDynamicsEngine.sample(
                prepProgress: motion.prepProgress,
                splitProgress: motion.splitProgress,
                settleProgress: motion.settleProgress,
                velocity: motion.gestureVelocity,
                energy: motion.branchEnergy,
                bias: motion.branchBias
            )
            let layout = PrototypeLayout(
                size: proxy.size,
                phase: motion.phase,
                prepProgress: motion.prepProgress,
                splitProgress: motion.splitProgress,
                settleProgress: motion.settleProgress,
                branchBias: motion.branchBias,
                branchEnergy: motion.branchEnergy,
                gestureVelocity: motion.gestureVelocity,
                inhale: birthDynamics.inhale,
                exhale: birthDynamics.exhale,
                aperture: birthDynamics.aperture,
                spitStrength: birthDynamics.spitStrength
            )
            let semantics = StageSemantics(
                phase: motion.phase,
                quality: motion.qualityReport.level,
                dynamics: birthDynamics
            )
            let tuningBinding = Binding<MotionTuning>(
                get: { motion.tuning },
                set: { motion.updateTuning($0) }
            )
            let autoAdaptBinding = Binding<Bool>(
                get: { motion.autoAdaptEnabled },
                set: { motion.setAutoAdapt($0) }
            )
            let presetBinding = Binding<MotionPreset>(
                get: { motion.selectedPreset },
                set: { motion.selectPreset($0) }
            )
            let activeProfileBinding = Binding<UUID>(
                get: { motion.activeProfileID ?? motion.profiles.first?.id ?? UUID() },
                set: { motion.selectActiveProfile(id: $0) }
            )
            let profileNameBinding = Binding<String>(
                get: { motion.profileDraftName },
                set: { motion.updateProfileDraftName($0) }
            )
            let profileNotesBinding = Binding<String>(
                get: { motion.profileDraftNotes },
                set: { motion.updateProfileDraftNotes($0) }
            )
            let profileTagsBinding = Binding<String>(
                get: { motion.profileDraftTags },
                set: { motion.updateProfileDraftTags($0) }
            )

            ZStack {
                AtmosphereBackground(
                    phase: motion.phase,
                    dynamics: birthDynamics
                )

                BirthMembraneLayer(
                    parentAnchor: layout.parentAnchor,
                    leftAnchor: layout.leftAnchor,
                    rightAnchor: layout.rightAnchor,
                    progress: layout.connectionProgress,
                    dynamics: birthDynamics
                )

                BirthConnectionLayer(
                    parentAnchor: layout.parentAnchor,
                    leftAnchor: layout.leftAnchor,
                    rightAnchor: layout.rightAnchor,
                    progress: layout.connectionProgress,
                    phase: motion.phase,
                    bias: motion.branchBias,
                    energy: motion.branchEnergy,
                    velocity: motion.gestureVelocity,
                    dynamics: birthDynamics
                )

                SpitBurstLayer(
                    parentAnchor: layout.parentAnchor,
                    leftAnchor: layout.leftAnchor,
                    rightAnchor: layout.rightAnchor,
                    progress: layout.connectionProgress,
                    dynamics: birthDynamics
                )

                LiquidPane(
                    title: semantics.parentTitle,
                    subtitle: semantics.parentSubtitle,
                    accent: semantics.parentAccent,
                    phaseLabel: motion.phase.rawValue,
                    openTop: true,
                    glow: motion.glowPulse,
                    chips: semantics.parentChips,
                    lineageLabel: semantics.parentLineage,
                    aperture: birthDynamics.aperture
                )
                .frame(width: layout.parentSize.width, height: layout.parentSize.height)
                .position(layout.parentCenter)
                .scaleEffect(layout.parentScale)
                .opacity(layout.parentOpacity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            motion.updateGesture(value: value)
                        }
                        .onEnded { _ in
                            motion.endGesture()
                        }
                )

                if motion.showsChildren || motion.splitProgress > 0 {
                    LiquidPane(
                        title: semantics.leftTitle,
                        subtitle: semantics.leftSubtitle,
                        accent: semantics.leftAccent,
                        phaseLabel: "child",
                        openTop: false,
                        glow: motion.settleProgress,
                        chips: semantics.leftChips,
                        lineageLabel: semantics.leftLineage,
                        aperture: 0
                    )
                    .frame(width: layout.childSize.width, height: layout.childSize.height)
                    .position(layout.leftCenter)
                    .scaleEffect(layout.childScale)
                    .opacity(layout.childOpacity)

                    LiquidPane(
                        title: semantics.rightTitle,
                        subtitle: semantics.rightSubtitle,
                        accent: semantics.rightAccent,
                        phaseLabel: "child",
                        openTop: false,
                        glow: motion.settleProgress,
                        chips: semantics.rightChips,
                        lineageLabel: semantics.rightLineage,
                        aperture: 0
                    )
                    .frame(width: layout.childSize.width, height: layout.childSize.height)
                    .position(layout.rightCenter)
                    .scaleEffect(layout.childScale)
                    .opacity(layout.childOpacity)
                }

                ControlDeck(
                    phase: motion.phase,
                    prepProgress: motion.prepProgress,
                    gestureThreshold: motion.tuning.gestureThreshold,
                    velocity: motion.gestureVelocity,
                    neck: birthDynamics.neckConstriction,
                    spit: birthDynamics.spitStrength,
                    quality: motion.qualityReport.level,
                    onPrimary: {
                        if motion.isBranched {
                            motion.reset()
                        } else {
                            motion.triggerBranch(trigger: .button)
                        }
                    },
                    onReplay: {
                        motion.reset()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 320_000_000)
                            motion.triggerBranch(trigger: .replay)
                        }
                    }
                )
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsTuning.toggle()
                        }
                    } label: {
                        Label(
                            showsTuning ? "Hide Motion Tuning" : "Show Motion Tuning",
                            systemImage: "slider.horizontal.3"
                        )
                        .font(.subheadline.weight(.regular))
                    }
                    .buttonStyle(.bordered)

                    if showsTuning {
                        MotionTuningPanel(
                            tuning: tuningBinding,
                            selectedPreset: presetBinding,
                            profiles: motion.profiles,
                            activeProfileID: activeProfileBinding,
                            profileIsDirty: motion.profileIsDirty,
                            profileName: profileNameBinding,
                            profileNotes: profileNotesBinding,
                            profileTags: profileTagsBinding,
                            autoAdaptEnabled: autoAdaptBinding,
                            onCreateProfile: { motion.createProfileFromCurrent() },
                            onDuplicateProfile: { motion.duplicateActiveProfile() },
                            onDeleteProfile: { motion.deleteActiveProfile() },
                            onSaveProfile: { motion.saveCurrentToActiveProfile() },
                            onRevertProfile: { motion.revertFromActiveProfile() },
                            onApplyPreset: {
                                motion.applySelectedPreset()
                            }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )

                        MotionTelemetryPanel(
                            quality: motion.qualityReport,
                            latestRun: motion.latestRun,
                            runs: Array(motion.runHistory.prefix(6)),
                            benchmarkReport: motion.benchmarkReport,
                            benchmarkHistory: Array(motion.benchmarkHistory.prefix(4)),
                            benchmarkRegression: motion.benchmarkRegression,
                            activeProfileName: motion.activeProfile?.name ?? "No Profile",
                            activeProfileHasBaseline: motion.activeProfile?.baseline != nil,
                            profileIsDirty: motion.profileIsDirty,
                            persistenceStatus: motion.persistenceStatus,
                            workspaceURL: motion.workspaceURL,
                            onRunBenchmark: {
                                motion.runBenchmarkSuite(recordHistory: true)
                            },
                            onSetBaseline: { motion.setBaselineFromCurrentBenchmark() },
                            onClearBaseline: { motion.clearBaselineForActiveProfile() },
                            onClearRuns: { motion.clearRunHistory() },
                            onClearBenchmarks: { motion.clearBenchmarkHistory() },
                            onSaveWorkspace: { motion.saveWorkspaceNow() },
                            onReloadWorkspace: { motion.reloadWorkspace() },
                            onExportWorkspace: { motion.exportWorkspaceToDesktop() },
                            onImportLatestWorkspace: { motion.importLatestDesktopExport() },
                            onExportReleaseGate: { motion.exportReleaseGateReportToDesktop() }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct StageSemantics {
    let parentTitle: String
    let parentSubtitle: String
    let parentAccent: Color
    let parentChips: [String]
    let parentLineage: String

    let leftTitle: String
    let leftSubtitle: String
    let leftAccent: Color
    let leftChips: [String]
    let leftLineage: String

    let rightTitle: String
    let rightSubtitle: String
    let rightAccent: Color
    let rightChips: [String]
    let rightLineage: String

    init(phase: BranchPhase, quality: MotionQualityLevel, dynamics: BirthDynamicsState) {
        let qualityToken: String
        switch quality {
        case .healthy:
            qualityToken = "stable"
        case .caution:
            qualityToken = "tuning"
        case .unstable:
            qualityToken = "guarded"
        }

        let lineageStrength = Int(dynamics.fluidTransfer * 100)
        let morphLine = "voice->chat gestation \(lineageStrength)%"

        switch phase {
        case .idle:
            parentTitle = "Voice Intent Surface"
            parentSubtitle = "Human-facing intake, awaiting expression shift."
            parentAccent = .cyan
            parentChips = ["voice", "context", qualityToken]
            parentLineage = "birth channel dormant"
        case .gesturing:
            parentTitle = "Voice to Chat Morph"
            parentSubtitle = "Identity preserved while form reconfigures."
            parentAccent = .teal
            parentChips = ["morph", "continuity", qualityToken]
            parentLineage = morphLine
        case .splitting:
            parentTitle = "Cognitive Spawn Trigger"
            parentSubtitle = "Parent context allocates two human-facing branches."
            parentAccent = .cyan
            parentChips = ["spawn", "lineage", qualityToken]
            parentLineage = "birth channel pressurizing"
        case .settling:
            parentTitle = "Lineage Stabilization"
            parentSubtitle = "Branch responsibilities settling into durable lanes."
            parentAccent = .blue
            parentChips = ["stabilize", "handoff", qualityToken]
            parentLineage = "offspring lanes stabilizing"
        case .branched:
            parentTitle = "Parent Context Ledger"
            parentSubtitle = "Global intent retained while branches execute."
            parentAccent = .indigo
            parentChips = ["ledger", "human-facing", qualityToken]
            parentLineage = "birth complete"
        }

        leftTitle = "Chat Workspace"
        leftSubtitle = "Dialogue-native reasoning surface."
        leftAccent = .mint
        leftChips = ["chat", "human", qualityToken]
        leftLineage = "born from voice context"

        rightTitle = "Toolchain Workspace"
        rightSubtitle = "Software chain orchestration surface."
        rightAccent = .blue
        rightChips = ["tools", "builds", qualityToken]
        rightLineage = "born from parent context"
    }
}

private struct PrototypeLayout {
    let parentCenter: CGPoint
    let parentAnchor: CGPoint
    let parentSize: CGSize
    let parentScale: CGFloat
    let parentOpacity: CGFloat

    let leftCenter: CGPoint
    let rightCenter: CGPoint
    let leftAnchor: CGPoint
    let rightAnchor: CGPoint
    let childSize: CGSize
    let childScale: CGFloat
    let childOpacity: CGFloat

    let connectionProgress: CGFloat

    init(
        size: CGSize,
        phase: BranchPhase,
        prepProgress: CGFloat,
        splitProgress: CGFloat,
        settleProgress: CGFloat,
        branchBias: CGFloat,
        branchEnergy: CGFloat,
        gestureVelocity: CGFloat,
        inhale: CGFloat,
        exhale: CGFloat,
        aperture: CGFloat,
        spitStrength: CGFloat
    ) {
        let prepCurve = Self.prepCurve(prepProgress)
        let splitCurve = Self.smootherStep(splitProgress)
        let settleCurve = Self.smootherStep(settleProgress)
        let splitLift = Self.clamped01((splitCurve * 0.72) + (spitStrength * 0.28))
        let bifurcation = Self.smootherStep(Self.clamped01((splitCurve - 0.42) / 0.58))
        let branchRelease = Self.clamped01((bifurcation * 0.82) + (spitStrength * 0.38))
        let settleWave = sin(settleCurve * .pi * 2.4) * exp(-2.8 * settleCurve) * (0.09 + (branchEnergy * 0.12))
        let settleLift = Self.clamped01(settleCurve + settleWave)
        let dynamicEnergy = min(1, branchEnergy + (gestureVelocity * 0.35))

        let baseWidth = Self.clamped(size.width * 0.36, min: 360, max: 560)
        let baseHeight = Self.clamped(size.height * 0.34, min: 230, max: 340)
        let splitEnergyBoost = 1 + (dynamicEnergy * 0.18)
        let inhaleInflate = inhale * 0.18
        let exhalePush = exhale * 0.16
        let recoilDrop = sin(settleCurve * .pi) * spitStrength * 22

        let parentWidth = baseWidth * (
            1 +
                (0.12 * prepCurve) +
                inhaleInflate -
                (0.24 * splitCurve * splitEnergyBoost) -
                (0.08 * exhalePush)
        )
        let parentHeight = baseHeight * (
            1 +
                (0.14 * inhale) -
                (0.2 * splitCurve) -
                (0.06 * exhalePush)
        )
        parentSize = CGSize(width: parentWidth, height: parentHeight)

        parentCenter = CGPoint(
            x: size.width * 0.5,
            y: (size.height * 0.64) -
                (34 * prepCurve) -
                (26 * splitCurve) -
                (12 * exhalePush) -
                (6 * dynamicEnergy) +
                recoilDrop
        )
        parentAnchor = CGPoint(
            x: parentCenter.x + (branchBias * 16 * splitCurve),
            y: parentCenter.y - (parentHeight * (0.22 + (0.15 * aperture) + (0.04 * dynamicEnergy)))
        )
        parentScale = 1 + (0.04 * inhale) - (0.08 * splitCurve)
        parentOpacity = 1 - (0.28 * splitCurve)

        let phaseBoost: CGFloat
        switch phase {
        case .gesturing:
            phaseBoost = 0.94
        case .splitting:
            phaseBoost = 1.08
        case .settling:
            phaseBoost = 1.02
        case .idle, .branched:
            phaseBoost = 1
        }

        let ejectionBoost = 1 + (spitStrength * 0.42) + (exhale * 0.22)
        let horizontalSpread =
            (Self.clamped(size.width * 0.23, min: 190, max: 340) * branchRelease * (1 + (0.22 * dynamicEnergy)) * ejectionBoost * phaseBoost) +
            (38 * settleLift)
        let verticalRise =
            (baseHeight * (0.56 + (0.08 * dynamicEnergy) + (0.18 * spitStrength)) * splitLift) +
            (28 * settleLift) +
            (12 * exhale)
        let settleInset = (1 - settleLift) * (34 + (18 * dynamicEnergy))
        let biasOffset = branchBias * (42 * branchRelease + (26 * dynamicEnergy) + (14 * spitStrength))

        childSize = CGSize(width: baseWidth * 0.62, height: baseHeight * 0.74)
        childScale = Self.clamped01(0.18 + (0.46 * splitLift) + (0.36 * branchRelease))
        childOpacity = Self.clamped01((splitLift * 0.76) + (branchRelease * 0.22) + (gestureVelocity * 0.06))

        var leftX = parentCenter.x - horizontalSpread + settleInset - biasOffset
        var rightX = parentCenter.x + horizontalSpread - settleInset + biasOffset
        let childVisualWidth = childSize.width * childScale
        let minGap = max(4, childVisualWidth * (0.04 + (0.2 * branchRelease)))
        let currentGap = rightX - leftX - childVisualWidth
        if currentGap < minGap {
            let correction = (minGap - currentGap) * 0.5
            leftX -= correction
            rightX += correction
        }

        let margin: CGFloat = 28
        let minCenter = margin + (childVisualWidth * 0.5)
        let maxCenter = size.width - margin - (childVisualWidth * 0.5)

        if leftX < minCenter {
            let shift = minCenter - leftX
            leftX += shift
            rightX += shift
        }
        if rightX > maxCenter {
            let shift = rightX - maxCenter
            leftX -= shift
            rightX -= shift
        }

        leftX = Self.clamped(leftX, min: minCenter, max: maxCenter)
        rightX = Self.clamped(rightX, min: minCenter, max: maxCenter)

        let childY = Self.clamped(
            parentCenter.y - verticalRise,
            min: (childSize.height * 0.55) + 24,
            max: size.height - (childSize.height * 0.55) - 24
        )

        leftCenter = CGPoint(x: leftX, y: childY)
        rightCenter = CGPoint(x: rightX, y: childY)

        leftAnchor = CGPoint(
            x: leftCenter.x,
            y: leftCenter.y + (childSize.height * 0.18 * childScale)
        )
        rightAnchor = CGPoint(
            x: rightCenter.x,
            y: rightCenter.y + (childSize.height * 0.18 * childScale)
        )

        connectionProgress = Self.clamped01(
            (0.18 * prepCurve) +
                (0.44 * splitLift) +
                (0.3 * branchRelease) +
                (0.2 * spitStrength) +
                (0.08 * gestureVelocity)
        )
    }

    private static func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }

    private static func clamped01(_ value: CGFloat) -> CGFloat {
        clamped(value, min: 0, max: 1)
    }

    private static func prepCurve(_ progress: CGFloat) -> CGFloat {
        let t = clamped01(progress)
        return 1 - pow(1 - t, 2.6)
    }

    private static func smootherStep(_ progress: CGFloat) -> CGFloat {
        let t = clamped01(progress)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}

private struct AtmosphereBackground: View {
    let phase: BranchPhase
    let dynamics: BirthDynamicsState

    var body: some View {
        let pulse = abs(dynamics.pulse)
        let envelope = dynamics.envelope
        let glowStrength = 0.12 + (pulse * 0.22) + (envelope * 0.14)
        let drift = dynamics.torsion * 90

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.1, blue: 0.15),
                    Color(red: 0.06, green: 0.14, blue: 0.21),
                    Color(red: 0.1, green: 0.12, blue: 0.21)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(glowStrength), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 720, height: 420)
                .offset(x: -160 + drift, y: -220)
                .blur(radius: 54)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.mint.opacity(glowStrength * 0.8), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 620, height: 360)
                .offset(x: 200 - drift, y: -140)
                .blur(radius: 58)

            if phase == .splitting || phase == .settling || phase == .branched {
                RadialGradient(
                    colors: [
                        .white.opacity(0.06 + (dynamics.fluidTransfer * 0.14)),
                        .blue.opacity(0.04 + (dynamics.membraneStretch * 0.1)),
                        .clear
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 580
                )
                .blendMode(.screen)
            }

            RoundedRectangle(cornerRadius: 0)
                .fill(.black.opacity(0.12))
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.02), .clear, .white.opacity(0.015)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

private struct BirthMembraneLayer: View {
    let parentAnchor: CGPoint
    let leftAnchor: CGPoint
    let rightAnchor: CGPoint
    let progress: CGFloat
    let dynamics: BirthDynamicsState

    var body: some View {
        let sheathWidth = 14 + (dynamics.sheathThickness * 28)
        let pulseBoost = abs(dynamics.pulse)
        let bifurcation = bifurcationFactor(progress: progress, spit: dynamics.spitStrength)
        let trunkFade = 1 - bifurcation
        let opacity = min(1, progress * 1.08) * (0.34 + (dynamics.membraneStretch * 0.36) + (trunkFade * 0.12))

        ZStack {
            trunkPath(from: parentAnchor, to: sharedAnchor)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.26 + (pulseBoost * 0.16)),
                            .cyan.opacity(0.24 + (dynamics.fluidTransfer * 0.22)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: sheathWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 9 + (dynamics.membraneStretch * 8))
                .blendMode(.screen)
                .opacity(0.68 * trunkFade)

            membranePath(from: parentAnchor, to: leftAnchor, side: -1, bifurcation: bifurcation)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24 + (pulseBoost * 0.14)),
                            .mint.opacity(0.2 + (dynamics.fluidTransfer * 0.2)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: sheathWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 8 + (dynamics.membraneStretch * 8))
                .blendMode(.screen)

            membranePath(from: parentAnchor, to: rightAnchor, side: 1, bifurcation: bifurcation)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24 + (pulseBoost * 0.14)),
                            .blue.opacity(0.2 + (dynamics.fluidTransfer * 0.18)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: sheathWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 8 + (dynamics.membraneStretch * 8))
                .blendMode(.screen)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.38 + (pulseBoost * 0.24)),
                            .cyan.opacity(0.22 + (dynamics.fluidTransfer * 0.2)),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 40
                    )
                )
                .frame(
                    width: 24 + (dynamics.neckConstriction * 26),
                    height: 24 + (dynamics.neckConstriction * 26)
                )
                .position(parentAnchor)
                .blur(radius: 1.6)
        }
        .opacity(opacity)
    }

    private var sharedAnchor: CGPoint {
        CGPoint(
            x: ((leftAnchor.x + rightAnchor.x) * 0.5) + (dynamics.torsion * 12),
            y: ((leftAnchor.y + rightAnchor.y) * 0.5) + (26 * (1 - dynamics.spitStrength))
        )
    }

    private func trunkPath(from parent: CGPoint, to child: CGPoint) -> Path {
        var path = Path()
        let lift = 18 + (36 * dynamics.inhale) + (20 * dynamics.exhale)
        path.move(to: CGPoint(x: parent.x, y: parent.y - (8 + (8 * dynamics.neckConstriction))))
        path.addCurve(
            to: child,
            control1: CGPoint(
                x: parent.x + (dynamics.torsion * 8),
                y: parent.y - lift
            ),
            control2: CGPoint(
                x: child.x - (dynamics.torsion * 14),
                y: child.y + (34 + (22 * dynamics.membraneStretch))
            )
        )
        return path
    }

    private func membranePath(
        from parent: CGPoint,
        to child: CGPoint,
        side: CGFloat,
        bifurcation: CGFloat
    ) -> Path {
        var path = Path()
        let lane = side * bifurcation
        let torsion = lane * dynamics.torsion
        let divergence = (34 + (74 * dynamics.membraneStretch) + (20 * torsion)) * bifurcation
        let archLift = 22 + (44 * dynamics.neckConstriction) + (14 * dynamics.fluidTransfer) + ((1 - bifurcation) * 30)
        let childPull = (42 + (42 * dynamics.fluidTransfer) - (12 * torsion)) * bifurcation
        let startShift = (8 + (24 * dynamics.neckConstriction)) * lane
        let target = mixPoint(sharedAnchor, child, amount: bifurcation)

        path.move(to: CGPoint(x: parent.x + startShift, y: parent.y - (8 + (8 * dynamics.neckConstriction))))
        path.addCurve(
            to: target,
            control1: CGPoint(x: parent.x + (divergence * side), y: parent.y - archLift),
            control2: CGPoint(
                x: target.x - (childPull * side),
                y: target.y + (38 + (26 * dynamics.membraneStretch))
            )
        )
        return path
    }

    private func bifurcationFactor(progress: CGFloat, spit: CGFloat) -> CGFloat {
        let late = clamped01((progress - 0.46) / 0.54)
        return clamped01((late * 0.72) + (spit * 0.38))
    }

    private func mixPoint(_ a: CGPoint, _ b: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: a.x + ((b.x - a.x) * amount),
            y: a.y + ((b.y - a.y) * amount)
        )
    }

    private func clamped01(_ value: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(1, value))
    }
}

private struct BirthConnectionLayer: View {
    let parentAnchor: CGPoint
    let leftAnchor: CGPoint
    let rightAnchor: CGPoint
    let progress: CGFloat
    let phase: BranchPhase
    let bias: CGFloat
    let energy: CGFloat
    let velocity: CGFloat
    let dynamics: BirthDynamicsState

    var body: some View {
        let dynamicEnergy = min(1, energy + (velocity * 0.45))
        let lineWidth = 2.8 + (dynamicEnergy * 1.8) + (dynamics.sheathThickness * 2.7)
        let pulseWidth = max(1.4, lineWidth * (0.28 + (abs(dynamics.pulse) * 0.22)))
        let opacityBoost = phase == .splitting ? 0.1 : 0
        let bifurcation = bifurcationFactor(progress: progress, spit: dynamics.spitStrength)
        let trunkFade = 1 - bifurcation

        ZStack {
            trunkPath(from: parentAnchor, to: sharedAnchor, energy: dynamicEnergy)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.84), .cyan.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth * 1.08, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.5)
                .opacity(0.82 * trunkFade)

            trunkPath(from: parentAnchor, to: sharedAnchor, energy: dynamicEnergy)
                .trim(from: 0, to: progress)
                .stroke(
                    .white.opacity(0.22 + (abs(dynamics.pulse) * 0.24)),
                    style: StrokeStyle(lineWidth: pulseWidth * 1.05, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.8)
                .opacity(0.78 * trunkFade)

            branchPath(
                from: parentAnchor,
                to: leftAnchor,
                side: -1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress,
                dynamics: dynamics,
                bifurcation: bifurcation
            )
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.82), .mint.opacity(0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.45)

            branchPath(
                from: parentAnchor,
                to: leftAnchor,
                side: -1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress,
                dynamics: dynamics,
                bifurcation: bifurcation
            )
                .trim(from: 0, to: progress)
                .stroke(
                    .white.opacity(0.24 + (abs(dynamics.pulse) * 0.26)),
                    style: StrokeStyle(lineWidth: pulseWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.8)

            branchPath(
                from: parentAnchor,
                to: rightAnchor,
                side: 1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress,
                dynamics: dynamics,
                bifurcation: bifurcation
            )
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.82), .blue.opacity(0.54)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.45)

            branchPath(
                from: parentAnchor,
                to: rightAnchor,
                side: 1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress,
                dynamics: dynamics,
                bifurcation: bifurcation
            )
                .trim(from: 0, to: progress)
                .stroke(
                    .white.opacity(0.24 + (abs(dynamics.pulse) * 0.26)),
                    style: StrokeStyle(lineWidth: pulseWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.8)

            Circle()
                .fill(.white.opacity(0.34 + (abs(dynamics.pulse) * 0.18)))
                .frame(width: 9 + (dynamics.neckConstriction * 10), height: 9 + (dynamics.neckConstriction * 10))
                .position(parentAnchor)
                .blur(radius: 0.6)
        }
        .opacity(min(1, progress + opacityBoost))
    }

    private var sharedAnchor: CGPoint {
        CGPoint(
            x: (leftAnchor.x + rightAnchor.x) * 0.5 + (dynamics.torsion * 10),
            y: (leftAnchor.y + rightAnchor.y) * 0.5 + (24 * (1 - dynamics.spitStrength))
        )
    }

    private func trunkPath(from parent: CGPoint, to child: CGPoint, energy: CGFloat) -> Path {
        var path = Path()
        let archLift = 18 + (52 * energy) + (20 * dynamics.neckConstriction)
        path.move(
            to: CGPoint(
                x: parent.x + (dynamics.torsion * 4),
                y: parent.y - (4 + (6 * energy) + (12 * dynamics.neckConstriction))
            )
        )
        path.addCurve(
            to: child,
            control1: CGPoint(
                x: parent.x + (dynamics.torsion * 12),
                y: parent.y - archLift
            ),
            control2: CGPoint(
                x: child.x - (dynamics.torsion * 16),
                y: child.y + (42 + (30 * energy))
            )
        )
        return path
    }

    private func branchPath(
        from parent: CGPoint,
        to child: CGPoint,
        side: CGFloat,
        bias: CGFloat,
        energy: CGFloat,
        progress: CGFloat,
        dynamics: BirthDynamicsState,
        bifurcation: CGFloat
    ) -> Path {
        var path = Path()
        let lane = side * bifurcation
        let directionalBias = lane * bias
        let torsion = lane * dynamics.torsion
        let divergence = (40 + (98 * energy) + (44 * dynamics.membraneStretch) - (20 * directionalBias) + (24 * torsion)) * bifurcation
        let archLift = 24 + (58 * energy) + (18 * progress) + (24 * dynamics.neckConstriction) + ((1 - bifurcation) * 26)
        let childPull = (54 + (54 * energy) + (26 * dynamics.fluidTransfer) + (18 * directionalBias)) * bifurcation
        let startShift = (14 + (14 * dynamics.neckConstriction) + (8 * energy) + (6 * directionalBias)) * lane
        let target = mixPoint(sharedAnchor, child, amount: bifurcation)

        path.move(
            to: CGPoint(
                x: parent.x + startShift,
                y: parent.y - (4 + (6 * energy) + (12 * dynamics.neckConstriction))
            )
        )
        path.addCurve(
            to: target,
            control1: CGPoint(x: parent.x + (divergence * side), y: parent.y - archLift),
            control2: CGPoint(
                x: target.x - (childPull * side),
                y: target.y + (42 + (32 * energy) + (14 * dynamics.fluidTransfer))
            )
        )
        return path
    }

    private func bifurcationFactor(progress: CGFloat, spit: CGFloat) -> CGFloat {
        let late = clamped01((progress - 0.46) / 0.54)
        return clamped01((late * 0.76) + (spit * 0.34))
    }

    private func mixPoint(_ a: CGPoint, _ b: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: a.x + ((b.x - a.x) * amount),
            y: a.y + ((b.y - a.y) * amount)
        )
    }

    private func clamped01(_ value: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(1, value))
    }
}

private struct SpitBurstLayer: View {
    let parentAnchor: CGPoint
    let leftAnchor: CGPoint
    let rightAnchor: CGPoint
    let progress: CGFloat
    let dynamics: BirthDynamicsState

    var body: some View {
        let burst = min(1, progress * 1.2) * dynamics.spitStrength
        let inhaleHalo = dynamics.inhale
        let bifurcation = clamped01((burst * 0.72) + (dynamics.exhale * 0.26))
        let jetHeight = 20 + (burst * 84)
        let jetWidth = 8 + (dynamics.aperture * 14) - (burst * 3)
        let dropletCount = 8

        ZStack {
            Circle()
                .strokeBorder(
                    .white.opacity(0.16 + (inhaleHalo * 0.26)),
                    lineWidth: 1.2 + (inhaleHalo * 2.4)
                )
                .frame(
                    width: 26 + (inhaleHalo * 52),
                    height: 26 + (inhaleHalo * 52)
                )
                .position(parentAnchor)
                .blur(radius: 0.5)
                .opacity(0.14 + (inhaleHalo * 0.36))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18 + (burst * 0.32)),
                            .cyan.opacity(0.1 + (burst * 0.18)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(3, jetWidth), height: jetHeight)
                .position(
                    x: parentAnchor.x + (dynamics.torsion * 5),
                    y: parentAnchor.y - (jetHeight * 0.5)
                )
                .blur(radius: 1.1)
                .opacity(0.12 + (burst * 0.54))

            ForEach(0..<dropletCount, id: \.self) { index in
                let side: CGFloat = index % 2 == 0 ? -1 : 1
                let laneIndex = CGFloat(index / 2)
                let laneOffset = laneIndex * 0.1
                let travel = min(1, burst * (0.96 + (dynamics.fluidTransfer * 0.25)))
                let pulseOffset = dynamics.pulse * 0.03 * (side > 0 ? 1 : -1)
                let t = clamped01((travel * 0.97) - laneOffset + 0.05 + pulseOffset)
                let point = lanePoint(side: side, t: t, bifurcation: bifurcation)
                let radius = 1.8 + (dynamics.spitStrength * 3.2) - (laneIndex * 0.14)
                let blur = 0.5 + (dynamics.spitStrength * 0.65)
                let opacity = Swift.max(0, Swift.min(1, 0.16 + (1 - laneOffset) * 0.52 + (dynamics.exhale * 0.26)))
                let tint = side < 0 ? Color.mint : Color.blue

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(opacity), tint.opacity(opacity * 0.7), .clear],
                            center: .center,
                            startRadius: 0.2,
                            endRadius: radius * 1.8
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(point)
                    .blur(radius: blur)
            }
        }
        .opacity(0.18 + (burst * 0.82))
        .blendMode(.screen)
    }

    private func lanePoint(side: CGFloat, t: CGFloat, bifurcation: CGFloat) -> CGPoint {
        let child = side < 0 ? leftAnchor : rightAnchor
        let laneSplit = smootherStep(clamped01((t - 0.46) / 0.54))
        let laneBifurcation = clamped01(bifurcation * laneSplit)
        let centerTarget = CGPoint(
            x: (leftAnchor.x + rightAnchor.x) * 0.5,
            y: (leftAnchor.y + rightAnchor.y) * 0.5 + (26 * (1 - laneBifurcation))
        )
        let target = mixPoint(centerTarget, child, amount: laneBifurcation)

        let torsion = side * laneBifurcation * dynamics.torsion
        let divergence = (28 + (64 * dynamics.spitStrength) + (22 * torsion)) * laneBifurcation
        let archLift = 16 + (34 * dynamics.exhale) + (12 * dynamics.fluidTransfer)
        let childPull = (32 + (44 * dynamics.spitStrength) - (14 * torsion)) * laneBifurcation
        let startShift = (4 + (22 * dynamics.aperture)) * side * laneBifurcation

        let p0 = CGPoint(
            x: parentAnchor.x + startShift,
            y: parentAnchor.y - (6 + (8 * dynamics.aperture))
        )
        let p1 = CGPoint(
            x: parentAnchor.x + (divergence * side),
            y: parentAnchor.y - archLift
        )
        let p2 = CGPoint(
            x: target.x - (childPull * side),
            y: target.y + (38 + (32 * dynamics.membraneStretch))
        )
        let p3 = target
        return cubicBezierPoint(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
    }

    private func cubicBezierPoint(
        t: CGFloat,
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint
    ) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        return CGPoint(
            x: (uuu * p0.x) + (3 * uu * t * p1.x) + (3 * u * tt * p2.x) + (ttt * p3.x),
            y: (uuu * p0.y) + (3 * uu * t * p1.y) + (3 * u * tt * p2.y) + (ttt * p3.y)
        )
    }

    private func clamped01(_ value: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(1, value))
    }

    private func smootherStep(_ value: CGFloat) -> CGFloat {
        let t = clamped01(value)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private func mixPoint(_ a: CGPoint, _ b: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: a.x + ((b.x - a.x) * amount),
            y: a.y + ((b.y - a.y) * amount)
        )
    }
}

private struct LiquidPane: View {
    let title: String
    let subtitle: String
    let accent: Color
    let phaseLabel: String
    let openTop: Bool
    let glow: CGFloat
    let chips: [String]
    let lineageLabel: String
    let aperture: CGFloat

    var body: some View {
        let gloss = 0.2 + (glow * 0.18)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(.white.opacity(0.97))
                    Text(subtitle)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer(minLength: 0)

                Text(phaseLabel.uppercased())
                    .font(.caption.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                ForEach(chips.prefix(3), id: \.self) { chip in
                    tag(chip)
                }
            }

            Text(lineageLabel.uppercased())
                .font(.caption2.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.08), in: Capsule())

            VStack(spacing: 10) {
                signalRow("Adaptive Signal", value: "89%")
                signalRow("Human-Centered Priority", value: "Active")
                signalRow("On-Device Inference", value: "Low Latency")
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22 + (0.08 * glow)),
                                accent.opacity(0.12 + (0.08 * glow)),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(gloss),
                                .white.opacity(0.02),
                                accent.opacity(0.08 + (0.12 * glow)),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22 + (0.1 * glow)),
                                .clear,
                                accent.opacity(0.32 + (0.12 * glow))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .overlay {
            paneStroke
        }
        .shadow(color: .black.opacity(0.32), radius: 30, x: 0, y: 20)
    }

    private var paneStroke: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.44), lineWidth: 1.15)

            if openTop {
                let holeWidth = 92 + (aperture * 70)
                let holeHeight = 7 + (aperture * 7)
                let lipWidth = holeWidth + 12 + (aperture * 8)
                let lipHeight = holeHeight + 5 + (aperture * 2)
                VStack {
                    ZStack {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: holeWidth, height: holeHeight)
                            .offset(y: -1 - (aperture * 1.8))
                            .blendMode(.destinationOut)

                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.42 + (aperture * 0.3)),
                                        .cyan.opacity(0.22 + (aperture * 0.28)),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: lipWidth, height: lipHeight)
                            .offset(y: -1 - (aperture * 2.2))
                            .blendMode(.screen)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .compositingGroup()
    }

    private func tag(_ value: String) -> some View {
        Text(value)
            .font(.footnote.weight(.regular))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.11), in: Capsule())
    }

    private func signalRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout.weight(.regular))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text(value)
                .font(.callout.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.96))
        }
    }
}

private struct ControlDeck: View {
    let phase: BranchPhase
    let prepProgress: CGFloat
    let gestureThreshold: CGFloat
    let velocity: CGFloat
    let neck: CGFloat
    let spit: CGFloat
    let quality: MotionQualityLevel
    let onPrimary: () -> Void
    let onReplay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrimary) {
                Label(
                    phase == .branched ? "Reset to Parent" : "Birth Two Branches",
                    systemImage: phase == .branched ? "arrow.clockwise" : "sparkles"
                )
                .font(.headline.weight(.regular))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)

            Button(action: onReplay) {
                Label("Replay Motion", systemImage: "play.fill")
                    .font(.headline.weight(.regular))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)

            Text("Phase: \(phase.rawValue)")
                .font(.subheadline.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())

            Text("Drag \u{2191} \(Int(prepProgress * 100))% / \(Int(gestureThreshold * 100))%")
                .font(.subheadline.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())

            Text("Velocity \(Int(velocity * 100))%")
                .font(.subheadline.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())

            Text("Neck \(Int(neck * 100))%")
                .font(.subheadline.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())

            Text("Spit \(Int(spit * 100))%")
                .font(.subheadline.monospaced().weight(.regular))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())

            HStack(spacing: 7) {
                Circle()
                    .fill(quality.color)
                    .frame(width: 8, height: 8)
                Text(quality.label)
                    .font(.subheadline.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.1), in: Capsule())
        }
        .padding(10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct MotionTuningPanel: View {
    @Binding var tuning: MotionTuning
    @Binding var selectedPreset: MotionPreset
    let profiles: [MotionProfile]
    @Binding var activeProfileID: UUID
    let profileIsDirty: Bool
    @Binding var profileName: String
    @Binding var profileNotes: String
    @Binding var profileTags: String
    @Binding var autoAdaptEnabled: Bool
    let onCreateProfile: () -> Void
    let onDuplicateProfile: () -> Void
    let onDeleteProfile: () -> Void
    let onSaveProfile: () -> Void
    let onRevertProfile: () -> Void
    let onApplyPreset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Motion Tuning")
                        .font(.headline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.96))
                    Text("Profile presets + adaptive controls + parameter sliders.")
                        .font(.footnote.weight(.regular))
                        .foregroundStyle(.white.opacity(0.74))
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $autoAdaptEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                Picker("Profile", selection: $activeProfileID) {
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)

                Button("New", action: onCreateProfile)
                    .buttonStyle(.bordered)
                Button("Dup", action: onDuplicateProfile)
                    .buttonStyle(.bordered)
                Button("Del", action: onDeleteProfile)
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Text(profileIsDirty ? "Profile: Unsaved Changes" : "Profile: Synced")
                    .font(.footnote.monospaced().weight(.regular))
                    .foregroundStyle(profileIsDirty ? .orange.opacity(0.9) : .mint.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.11), in: Capsule())

                Button("Save Profile", action: onSaveProfile)
                    .buttonStyle(.bordered)
                Button("Revert", action: onRevertProfile)
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Profile Name", text: $profileName)
                    .textFieldStyle(.roundedBorder)

                TextField("Tags (comma-separated)", text: $profileTags)
                    .textFieldStyle(.roundedBorder)

                TextField("Notes", text: $profileNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            HStack(spacing: 8) {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(MotionPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Button("Apply") {
                    onApplyPreset()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Text(autoAdaptEnabled ? "Auto-adapt: On" : "Auto-adapt: Off")
                    .font(.footnote.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.11), in: Capsule())

                Button("Normalize") {
                    tuning = tuning.normalized()
                }
                .buttonStyle(.bordered)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(
                        "Split Stiffness",
                        value: $tuning.splitStiffness,
                        range: MotionTuning.splitStiffnessRange,
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Split Damping",
                        value: $tuning.splitDamping,
                        range: MotionTuning.splitDampingRange,
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Settle Stiffness",
                        value: $tuning.settleStiffness,
                        range: MotionTuning.settleStiffnessRange,
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Settle Damping",
                        value: $tuning.settleDamping,
                        range: MotionTuning.settleDampingRange,
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Pre-Split Delay",
                        value: $tuning.preSplitDelay,
                        range: MotionTuning.preSplitDelayRange,
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Gesture Commit Delay",
                        value: $tuning.gestureCommitDelay,
                        range: MotionTuning.gestureCommitDelayRange,
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Pre-Settle Delay",
                        value: $tuning.preSettleDelay,
                        range: MotionTuning.preSettleDelayRange,
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Post-Settle Delay",
                        value: $tuning.postSettleDelay,
                        range: MotionTuning.postSettleDelayRange,
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Gesture Threshold",
                        value: Binding<Double>(
                            get: { Double(tuning.gestureThreshold) },
                            set: { tuning.gestureThreshold = CGFloat($0) }
                        ),
                        range: asDoubleRange(MotionTuning.gestureThresholdRange),
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Pull Distance",
                        value: Binding<Double>(
                            get: { Double(tuning.pullDistance) },
                            set: { tuning.pullDistance = CGFloat($0) }
                        ),
                        range: asDoubleRange(MotionTuning.pullDistanceRange),
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Velocity Scale",
                        value: Binding<Double>(
                            get: { Double(tuning.velocityScale) },
                            set: { tuning.velocityScale = CGFloat($0) }
                        ),
                        range: asDoubleRange(MotionTuning.velocityScaleRange),
                        fractionDigits: 0
                    )
                    sliderRow(
                        "Velocity Influence",
                        value: Binding<Double>(
                            get: { Double(tuning.velocityInfluence) },
                            set: { tuning.velocityInfluence = CGFloat($0) }
                        ),
                        range: asDoubleRange(MotionTuning.velocityInfluenceRange),
                        fractionDigits: 2
                    )
                    sliderRow(
                        "Bias Influence",
                        value: Binding<Double>(
                            get: { Double(tuning.biasInfluence) },
                            set: { tuning.biasInfluence = CGFloat($0) }
                        ),
                        range: asDoubleRange(MotionTuning.biasInfluenceRange),
                        fractionDigits: 2
                    )
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(16)
        .frame(width: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        fractionDigits: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.white.opacity(0.84))
                Spacer(minLength: 0)
                Text(value.wrappedValue, format: .number.precision(.fractionLength(fractionDigits)))
                    .font(.footnote.monospacedDigit().weight(.regular))
                    .foregroundStyle(.white.opacity(0.92))
            }
            Slider(value: value, in: range)
                .tint(.white.opacity(0.9))
        }
    }

    private func asDoubleRange(_ range: ClosedRange<CGFloat>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }
}

private struct MotionTelemetryPanel: View {
    let quality: MotionQualityReport
    let latestRun: MotionRunMetrics?
    let runs: [MotionRunMetrics]
    let benchmarkReport: MotionBenchmarkReport?
    let benchmarkHistory: [MotionBenchmarkReport]
    let benchmarkRegression: MotionBenchmarkRegression?
    let activeProfileName: String
    let activeProfileHasBaseline: Bool
    let profileIsDirty: Bool
    let persistenceStatus: String
    let workspaceURL: URL
    let onRunBenchmark: () -> Void
    let onSetBaseline: () -> Void
    let onClearBaseline: () -> Void
    let onClearRuns: () -> Void
    let onClearBenchmarks: () -> Void
    let onSaveWorkspace: () -> Void
    let onReloadWorkspace: () -> Void
    let onExportWorkspace: () -> Void
    let onImportLatestWorkspace: () -> Void
    let onExportReleaseGate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(quality.level.color)
                        .frame(width: 8, height: 8)
                    Text("Quality: \(quality.level.label)")
                        .font(.headline.monospaced().weight(.regular))
                        .foregroundStyle(.white.opacity(0.94))
                }
                Spacer(minLength: 0)
                Button("Run Benchmark", action: onRunBenchmark)
                    .buttonStyle(.borderedProminent)
                Button("Clear Runs", action: onClearRuns)
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Text("Profile: \(activeProfileName)")
                    .font(.footnote.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.11), in: Capsule())
                if profileIsDirty {
                    Text("Unsaved")
                        .font(.footnote.monospaced().weight(.regular))
                        .foregroundStyle(.orange.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.11), in: Capsule())
                }
            }

            ForEach(quality.messages, id: \.self) { message in
                Text(message)
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.white.opacity(0.78))
            }

            if let benchmarkReport {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Benchmark \(benchmarkReport.grade.rawValue)")
                            .font(.subheadline.monospaced().weight(.regular))
                            .foregroundStyle(benchmarkReport.grade.color.opacity(0.94))
                        Text(
                            "\(Int(benchmarkReport.overallScore)) / \(Int(benchmarkReport.consistencyScore))"
                        )
                        .font(.subheadline.monospaced().weight(.regular))
                        .foregroundStyle(.white.opacity(0.84))
                        Spacer(minLength: 0)
                        Button("Clear Bench", action: onClearBenchmarks)
                            .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        Button(activeProfileHasBaseline ? "Update Baseline" : "Set Baseline", action: onSetBaseline)
                            .buttonStyle(.bordered)
                        if activeProfileHasBaseline {
                            Button("Clear Baseline", action: onClearBaseline)
                                .buttonStyle(.bordered)
                        }
                    }

                    ForEach(benchmarkReport.scenarios.prefix(4)) { scenario in
                        HStack {
                            Text(scenario.scenarioName)
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer(minLength: 0)
                            Text("\(Int(scenario.score))")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.92))
                            Text("pts")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.68))
                            Text(
                                "\(scenario.estimatedDuration, format: .number.precision(.fractionLength(2)))s"
                            )
                            .font(.caption.monospaced().weight(.regular))
                            .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    if let previous = benchmarkHistory.dropFirst().first {
                        let delta = benchmarkReport.overallScore - previous.overallScore
                        HStack(spacing: 6) {
                            Text("Benchmark Delta")
                                .font(.caption.weight(.regular))
                                .foregroundStyle(.white.opacity(0.74))
                            Text(delta, format: .number.precision(.fractionLength(1)))
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(delta >= 0 ? .mint.opacity(0.9) : .orange.opacity(0.9))
                        }
                    }

                    if let regression = benchmarkRegression {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Regression: \(regression.status.label)")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(regression.status.color.opacity(0.9))
                            Text(
                                "Δoverall \(regression.overallDelta, format: .number.precision(.fractionLength(1)))  Δconsistency \(regression.consistencyDelta, format: .number.precision(.fractionLength(1)))  worst \(regression.worstScenarioDelta, format: .number.precision(.fractionLength(1)))"
                            )
                            .font(.caption.monospaced().weight(.regular))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(2)
                            ForEach(regression.messages, id: \.self) { message in
                                Text(message)
                                    .font(.caption.weight(.regular))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                    } else {
                        Text("No baseline assigned for active profile.")
                            .font(.caption.weight(.regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.top, 4)
            }

            if let latestRun {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest Run")
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(
                        "\(latestRun.trigger.rawValue.uppercased())  \(latestRun.totalDuration, format: .number.precision(.fractionLength(2)))s"
                    )
                    .font(.footnote.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.88))
                    PhaseTimingBar(phases: latestRun.phases)
                }
            }

            if !runs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Runs")
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.92))
                    ForEach(runs) { run in
                        HStack {
                            Text(run.trigger.rawValue.uppercased())
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 62, alignment: .leading)
                            Text(run.totalDuration, format: .number.precision(.fractionLength(2)))
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.88))
                            Text("s")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer(minLength: 0)
                            Text("v\(Int(run.velocityPeak * 100))")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.72))
                            Text("b\(Int(abs(run.biasPeak) * 100))")
                                .font(.caption.monospaced().weight(.regular))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Workspace")
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.white.opacity(0.92))
                Text(persistenceStatus)
                    .font(.caption.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.82))
                Text(workspaceURL.path)
                    .font(.caption.monospaced().weight(.regular))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Button("Save", action: onSaveWorkspace)
                            .buttonStyle(.bordered)
                        Button("Reload", action: onReloadWorkspace)
                            .buttonStyle(.bordered)
                        Button("Export JSON", action: onExportWorkspace)
                            .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        Button("Import Latest", action: onImportLatestWorkspace)
                            .buttonStyle(.bordered)
                        Button("Export Gate", action: onExportReleaseGate)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PhaseTimingBar: View {
    let phases: MotionPhaseDurations

    var body: some View {
        let total = max(0.01, phases.total)
        GeometryReader { proxy in
            let width = proxy.size.width
            let preSplitWidth = max(2, width * CGFloat(phases.preSplit / total))
            let preSettleWidth = max(2, width * CGFloat(phases.preSettle / total))
            let settleWidth = max(2, width * CGFloat(phases.settleTail / total))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.26))
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.88))
                        .frame(width: preSplitWidth)
                    Rectangle()
                        .fill(Color.mint.opacity(0.86))
                        .frame(width: preSettleWidth)
                    Rectangle()
                        .fill(Color.blue.opacity(0.84))
                        .frame(width: settleWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .frame(height: 10)
    }
}

private extension MotionQualityLevel {
    var color: Color {
        switch self {
        case .healthy:
            .mint
        case .caution:
            .orange
        case .unstable:
            .red
        }
    }

    var label: String {
        switch self {
        case .healthy:
            "Healthy"
        case .caution:
            "Caution"
        case .unstable:
            "Unstable"
        }
    }
}

private extension MotionBenchmarkGrade {
    var color: Color {
        switch self {
        case .a:
            .mint
        case .b:
            .cyan
        case .c:
            .orange
        case .d:
            .red
        }
    }
}

private extension MotionBenchmarkRegressionStatus {
    var color: Color {
        switch self {
        case .pass:
            .mint
        case .warning:
            .orange
        case .fail:
            .red
        }
    }

    var label: String {
        switch self {
        case .pass:
            "PASS"
        case .warning:
            "WARN"
        case .fail:
            "FAIL"
        }
    }
}
