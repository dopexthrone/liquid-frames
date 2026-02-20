import SwiftUI

struct PrototypeRootView: View {
    @StateObject private var motion = BranchMotionDirector()
    @State private var showsTuning = true

    var body: some View {
        GeometryReader { proxy in
            let layout = PrototypeLayout(
                size: proxy.size,
                phase: motion.phase,
                prepProgress: motion.prepProgress,
                splitProgress: motion.splitProgress,
                settleProgress: motion.settleProgress,
                branchBias: motion.branchBias,
                branchEnergy: motion.branchEnergy,
                gestureVelocity: motion.gestureVelocity
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

            ZStack {
                AtmosphereBackground()

                BirthConnectionLayer(
                    parentAnchor: layout.parentAnchor,
                    leftAnchor: layout.leftAnchor,
                    rightAnchor: layout.rightAnchor,
                    progress: layout.connectionProgress,
                    phase: motion.phase,
                    bias: motion.branchBias,
                    energy: motion.branchEnergy,
                    velocity: motion.gestureVelocity
                )

                LiquidPane(
                    title: "Root Cognitive Window",
                    subtitle: "Adaptive state orchestration",
                    accent: .cyan,
                    phaseLabel: motion.phase.rawValue,
                    openTop: true,
                    glow: motion.glowPulse
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
                        title: "Branch A",
                        subtitle: "Intent-focused refinement",
                        accent: .mint,
                        phaseLabel: "child",
                        openTop: false,
                        glow: motion.settleProgress
                    )
                    .frame(width: layout.childSize.width, height: layout.childSize.height)
                    .position(layout.leftCenter)
                    .scaleEffect(layout.childScale)
                    .opacity(layout.childOpacity)

                    LiquidPane(
                        title: "Branch B",
                        subtitle: "Memory synthesis track",
                        accent: .blue,
                        phaseLabel: "child",
                        openTop: false,
                        glow: motion.settleProgress
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
                            onExportWorkspace: { motion.exportWorkspaceToDesktop() }
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
        gestureVelocity: CGFloat
    ) {
        let prepCurve = Self.prepCurve(prepProgress)
        let splitCurve = Self.smootherStep(splitProgress)
        let settleCurve = Self.smootherStep(settleProgress)
        let settleWave = sin(settleCurve * .pi * 2.4) * exp(-2.8 * settleCurve) * (0.09 + (branchEnergy * 0.12))
        let settleLift = Self.clamped01(settleCurve + settleWave)
        let dynamicEnergy = min(1, branchEnergy + (gestureVelocity * 0.35))

        let baseWidth = Self.clamped(size.width * 0.36, min: 360, max: 560)
        let baseHeight = Self.clamped(size.height * 0.34, min: 230, max: 340)
        let splitEnergyBoost = 1 + (dynamicEnergy * 0.18)

        let parentWidth = baseWidth * (1 + (0.16 * prepCurve) - (0.26 * splitCurve * splitEnergyBoost))
        let parentHeight = baseHeight * (1 - (0.1 * prepCurve) - (0.18 * splitCurve))
        parentSize = CGSize(width: parentWidth, height: parentHeight)

        parentCenter = CGPoint(
            x: size.width * 0.5,
            y: (size.height * 0.63) - (38 * prepCurve) - (24 * splitCurve) - (6 * dynamicEnergy)
        )
        parentAnchor = CGPoint(
            x: parentCenter.x + (branchBias * 18 * splitCurve),
            y: parentCenter.y - (parentHeight * (0.2 + (0.05 * dynamicEnergy)))
        )
        parentScale = 1 - (0.06 * splitCurve)
        parentOpacity = 1 - (0.3 * splitCurve)

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

        let horizontalSpread =
            (Self.clamped(size.width * 0.23, min: 190, max: 340) * splitCurve * (1 + (0.22 * dynamicEnergy)) * phaseBoost) +
            (38 * settleLift)
        let verticalRise = (baseHeight * (0.58 + (0.08 * dynamicEnergy)) * splitCurve) + (28 * settleLift)
        let settleInset = (1 - settleLift) * (34 + (18 * dynamicEnergy))
        let biasOffset = branchBias * (42 * splitCurve + (26 * dynamicEnergy))

        childSize = CGSize(width: baseWidth * 0.62, height: baseHeight * 0.74)
        childScale = Self.clamped01(0.3 + (0.7 * splitCurve) + (0.06 * dynamicEnergy))
        childOpacity = Self.clamped01(splitCurve + (gestureVelocity * 0.08))

        var leftX = parentCenter.x - horizontalSpread + settleInset - biasOffset
        var rightX = parentCenter.x + horizontalSpread - settleInset + biasOffset
        let childVisualWidth = childSize.width * childScale
        let minGap = max(30, childVisualWidth * 0.22)
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

        connectionProgress = Self.clamped01((0.25 * prepCurve) + (0.75 * splitCurve) + (gestureVelocity * 0.08))
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
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.16),
                    Color(red: 0.07, green: 0.16, blue: 0.22),
                    Color(red: 0.12, green: 0.13, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.white.opacity(0.2), .clear],
                center: .center,
                startRadius: 80,
                endRadius: 620
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
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

    var body: some View {
        let dynamicEnergy = min(1, energy + (velocity * 0.45))
        let lineWidth = 3.6 + (dynamicEnergy * 2.2)
        let opacityBoost = phase == .splitting ? 0.1 : 0

        ZStack {
            branchPath(
                from: parentAnchor,
                to: leftAnchor,
                side: -1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress
            )
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .mint.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.5)

            branchPath(
                from: parentAnchor,
                to: rightAnchor,
                side: 1,
                bias: bias,
                energy: dynamicEnergy,
                progress: progress
            )
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .blue.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.5)
        }
        .opacity(min(1, progress + opacityBoost))
    }

    private func branchPath(
        from parent: CGPoint,
        to child: CGPoint,
        side: CGFloat,
        bias: CGFloat,
        energy: CGFloat,
        progress: CGFloat
    ) -> Path {
        var path = Path()
        let directionalBias = side * bias
        let divergence = 78 + (92 * energy) - (20 * directionalBias)
        let archLift = 24 + (58 * energy) + (18 * progress)
        let childPull = 68 + (54 * energy) + (18 * directionalBias)
        let startShift = (18 + (8 * energy) + (6 * directionalBias)) * side

        path.move(to: CGPoint(x: parent.x + startShift, y: parent.y - (4 + (6 * energy))))
        path.addCurve(
            to: child,
            control1: CGPoint(x: parent.x + (divergence * side), y: parent.y - archLift),
            control2: CGPoint(x: child.x - (childPull * side), y: child.y + (42 + (32 * energy)))
        )
        return path
    }
}

private struct LiquidPane: View {
    let title: String
    let subtitle: String
    let accent: Color
    let phaseLabel: String
    let openTop: Bool
    let glow: CGFloat

    var body: some View {
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
                tag("Context")
                tag("Intent")
                tag("Memory")
            }

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
                VStack {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 112, height: 9)
                        .offset(y: -2)
                        .blendMode(.destinationOut)
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

                HStack(spacing: 8) {
                    Button("Save", action: onSaveWorkspace)
                        .buttonStyle(.bordered)
                    Button("Reload", action: onReloadWorkspace)
                        .buttonStyle(.bordered)
                    Button("Export JSON", action: onExportWorkspace)
                        .buttonStyle(.bordered)
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
