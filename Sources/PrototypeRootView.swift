import SwiftUI

struct PrototypeRootView: View {
    @StateObject private var motion = BranchMotionDirector()
    @State private var showsTuning = true

    var body: some View {
        GeometryReader { proxy in
            let layout = PrototypeLayout(
                size: proxy.size,
                prepProgress: motion.prepProgress,
                splitProgress: motion.splitProgress,
                settleProgress: motion.settleProgress
            )
            let tuningBinding = Binding<MotionTuning>(
                get: { motion.tuning },
                set: { motion.tuning = $0 }
            )

            ZStack {
                AtmosphereBackground()

                BirthConnectionLayer(
                    parentAnchor: layout.parentAnchor,
                    leftAnchor: layout.leftAnchor,
                    rightAnchor: layout.rightAnchor,
                    progress: layout.connectionProgress
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
                            motion.updateGesture(translation: value.translation)
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
                    onPrimary: {
                        if motion.isBranched {
                            motion.reset()
                        } else {
                            motion.triggerBranch()
                        }
                    },
                    onReplay: {
                        motion.reset()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 320_000_000)
                            motion.triggerBranch()
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
                        MotionTuningPanel(tuning: tuningBinding)
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

    init(size: CGSize, prepProgress: CGFloat, splitProgress: CGFloat, settleProgress: CGFloat) {
        let baseWidth = Self.clamped(size.width * 0.36, min: 360, max: 560)
        let baseHeight = Self.clamped(size.height * 0.34, min: 230, max: 340)

        let parentWidth = baseWidth * (1 + (0.14 * prepProgress) - (0.25 * splitProgress))
        let parentHeight = baseHeight * (1 - (0.09 * prepProgress) - (0.2 * splitProgress))
        parentSize = CGSize(width: parentWidth, height: parentHeight)

        parentCenter = CGPoint(
            x: size.width * 0.5,
            y: (size.height * 0.63) - (34 * prepProgress) - (20 * splitProgress)
        )
        parentAnchor = CGPoint(
            x: parentCenter.x,
            y: parentCenter.y - (parentHeight * 0.2)
        )
        parentScale = 1 - (0.05 * splitProgress)
        parentOpacity = 1 - (0.32 * splitProgress)

        let horizontalSpread = (Self.clamped(size.width * 0.23, min: 190, max: 340) * splitProgress) + (36 * settleProgress)
        let verticalRise = (baseHeight * 0.56 * splitProgress) + (26 * settleProgress)
        let settleInset = (1 - settleProgress) * 34

        leftCenter = CGPoint(
            x: parentCenter.x - horizontalSpread + settleInset,
            y: parentCenter.y - verticalRise
        )
        rightCenter = CGPoint(
            x: parentCenter.x + horizontalSpread - settleInset,
            y: parentCenter.y - verticalRise
        )

        childSize = CGSize(width: baseWidth * 0.62, height: baseHeight * 0.74)
        childScale = 0.34 + (0.66 * splitProgress)
        childOpacity = splitProgress

        leftAnchor = CGPoint(
            x: leftCenter.x,
            y: leftCenter.y + (childSize.height * 0.2 * childScale)
        )
        rightAnchor = CGPoint(
            x: rightCenter.x,
            y: rightCenter.y + (childSize.height * 0.2 * childScale)
        )

        connectionProgress = (0.25 * prepProgress) + (0.75 * splitProgress)
    }

    private static func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
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

    var body: some View {
        ZStack {
            branchPath(from: parentAnchor, to: leftAnchor)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .mint.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.5)

            branchPath(from: parentAnchor, to: rightAnchor)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.75), .blue.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.5)
        }
        .opacity(progress)
    }

    private func branchPath(from parent: CGPoint, to child: CGPoint) -> Path {
        var path = Path()
        let direction: CGFloat = child.x < parent.x ? -1 : 1
        path.move(to: CGPoint(x: parent.x + (20 * direction), y: parent.y - 4))
        path.addCurve(
            to: child,
            control1: CGPoint(x: parent.x + (80 * direction), y: parent.y - 26),
            control2: CGPoint(x: child.x - (70 * direction), y: child.y + 44)
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
        }
        .padding(10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct MotionTuningPanel: View {
    @Binding var tuning: MotionTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Motion Tuning")
                .font(.headline.weight(.regular))
                .foregroundStyle(.white.opacity(0.96))

            Text("Drag upward on parent pane to trigger branch birth.")
                .font(.footnote.weight(.regular))
                .foregroundStyle(.white.opacity(0.76))

            sliderRow(
                "Split Stiffness",
                value: $tuning.splitStiffness,
                range: 120...280,
                fractionDigits: 0
            )
            sliderRow(
                "Split Damping",
                value: $tuning.splitDamping,
                range: 10...34,
                fractionDigits: 0
            )
            sliderRow(
                "Settle Stiffness",
                value: $tuning.settleStiffness,
                range: 90...230,
                fractionDigits: 0
            )
            sliderRow(
                "Settle Damping",
                value: $tuning.settleDamping,
                range: 8...28,
                fractionDigits: 0
            )
            sliderRow(
                "Pre-Split Delay",
                value: $tuning.preSplitDelay,
                range: 0...0.8,
                fractionDigits: 2
            )
            sliderRow(
                "Pre-Settle Delay",
                value: $tuning.preSettleDelay,
                range: 0.2...1.2,
                fractionDigits: 2
            )
            sliderRow(
                "Gesture Threshold",
                value: Binding<Double>(
                    get: { Double(tuning.gestureThreshold) },
                    set: { tuning.gestureThreshold = CGFloat($0) }
                ),
                range: 0.4...0.9,
                fractionDigits: 2
            )
            sliderRow(
                "Pull Distance",
                value: Binding<Double>(
                    get: { Double(tuning.pullDistance) },
                    set: { tuning.pullDistance = CGFloat($0) }
                ),
                range: 120...320,
                fractionDigits: 0
            )
        }
        .padding(16)
        .frame(width: 312)
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
}
