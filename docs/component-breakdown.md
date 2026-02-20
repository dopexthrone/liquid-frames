# Component Breakdown

## 1) `LiquidFramesApp` (App Shell)

- Entry point and desktop window container.
- Owns scene lifecycle and minimum prototype window size.

## 2) `PrototypeRootView` (Composition Layer)

- Builds the full stage with:
  - atmospheric background
  - parent pane
  - child panes
  - birth-branch connection strokes
  - bottom control deck
- Reads motion state and maps it into adaptive geometry.

## 3) `BranchMotionDirector` (Motion State Machine)

- Single source of truth for animation phases:
  - `idle`
  - `gesturing`
  - `splitting`
  - `settling`
  - `branched`
- Emits animatable progress values:
  - `prepProgress`
  - `splitProgress`
  - `settleProgress`
  - `glowPulse`
- Emits motion-shaping signals:
  - `gestureVelocity`
  - `branchBias`
  - `branchEnergy`
- Coordinates timing and spring choreography for the branch sequence.
- Records run telemetry and produces quality/adaptation feedback for iterative tuning.
- Applies velocity-dependent spring modulation to keep split/settle behavior stable under fast input.
- Manages profile library state, active-profile dirty tracking, baselines, and regression checks.

## 4) `MotionIntelligence` (Core Motion Domain Layer)

- Defines `MotionTuning`, validated ranges, and normalization.
- Provides developer presets via `MotionPreset` (`Balanced`, `Responsive`, `Cinematic`).
- Implements `GestureSignalEstimator` so gesture parsing is deterministic and testable.
- Implements `MotionQualityEvaluator` for reliability scoring.
- Implements `MotionAdaptiveEngine` for continuously self-improving profile adjustments.
- Implements snapshot models for persistence/export and benchmark models for deterministic scoring.
- Implements benchmark baseline + regression evaluator (`pass`/`warning`/`fail`) for profile-level quality gates.

## 5) `MotionStorage` (Workspace Persistence)

- Saves and loads workspace snapshots as JSON.
- Uses default location: `~/Library/Application Support/liquid-frames/motion-workspace.json`.
- Supports explicit export snapshots for team sharing and build archives.

## 6) `PrototypeLayout` (Adaptive Layout Engine)

- Converts window size + motion progress into:
  - pane sizes
  - pane centers
  - anchor points for branch lines
  - opacity/scale transforms
- Keeps the motion legible across iMac and MacBook-style aspect ratios.
- Applies branch spacing/collision guardrails and viewport boundary clamping at large and small sizes.

## 7) `LiquidPane` (Glass Card Primitive)

- Shared pane UI primitive for parent/children.
- Uses material-backed surfaces, soft highlight gradients, and open-top stroke option.
- Encodes readable information density without breaking visual hierarchy.

## 8) `BirthConnectionLayer` (Liquid Branch Strokes)

- Draws two curved paths that emerge from the parent and connect to children.
- Uses progressive trim and glow-stroke styling to sell “birth” continuity.
- Deforms branch curvature and line energy in response to drag velocity and directional bias.

## 9) `ControlDeck` (Interaction Controls)

- Primary action toggles between branch and reset.
- Replay action re-runs the full sequence.
- Surfaces current phase, live drag threshold progress, and current quality state.

## 10) `MotionTuningPanel` (Live Calibration)

- Exposes named profile controls plus presets, auto-adapt toggle, spring/delay values, and gesture shaping values.
- Enables rapid calibration of "birth" feel during demo iteration.

## 11) `MotionTelemetryPanel` (Reliability Feedback)

- Displays quality report with warnings from the evaluator.
- Displays latest run phase timing breakdown and recent-run summary rows.
- Displays deterministic benchmark report/grade and benchmark deltas.
- Displays baseline regression status and profile-level benchmark deltas.
- Supports run/benchmark clearing and workspace save/reload/export controls.

## 12) `Tests/liquid-framesTests/MotionIntelligenceTests.swift` (Verification)

- Validates tuning range normalization.
- Validates gesture signal response behavior.
- Validates adaptive engine behavior for slow runs.
- Validates quality evaluator instability detection.
- Validates benchmark determinism for fixed profiles.
- Validates workspace snapshot save/load roundtrip.
