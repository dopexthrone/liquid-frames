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

## 4) `MotionIntelligence` (Core Motion Domain Layer)

- Defines `MotionTuning`, validated ranges, and normalization.
- Provides developer presets via `MotionPreset` (`Balanced`, `Responsive`, `Cinematic`).
- Implements `GestureSignalEstimator` so gesture parsing is deterministic and testable.
- Implements `MotionQualityEvaluator` for reliability scoring.
- Implements `MotionAdaptiveEngine` for continuously self-improving profile adjustments.

## 5) `PrototypeLayout` (Adaptive Layout Engine)

- Converts window size + motion progress into:
  - pane sizes
  - pane centers
  - anchor points for branch lines
  - opacity/scale transforms
- Keeps the motion legible across iMac and MacBook-style aspect ratios.

## 6) `LiquidPane` (Glass Card Primitive)

- Shared pane UI primitive for parent/children.
- Uses material-backed surfaces, soft highlight gradients, and open-top stroke option.
- Encodes readable information density without breaking visual hierarchy.

## 7) `BirthConnectionLayer` (Liquid Branch Strokes)

- Draws two curved paths that emerge from the parent and connect to children.
- Uses progressive trim and glow-stroke styling to sell “birth” continuity.
- Deforms branch curvature and line energy in response to drag velocity and directional bias.

## 8) `ControlDeck` (Interaction Controls)

- Primary action toggles between branch and reset.
- Replay action re-runs the full sequence.
- Surfaces current phase, live drag threshold progress, and current quality state.

## 9) `MotionTuningPanel` (Live Calibration)

- Exposes presets, auto-adapt toggle, spring/delay values, and gesture shaping values.
- Enables rapid calibration of "birth" feel during demo iteration.

## 10) `MotionTelemetryPanel` (Reliability Feedback)

- Displays quality report with warnings from the evaluator.
- Displays latest run phase timing breakdown and recent-run summary rows.
- Supports clearing run history to restart a calibration session.

## 11) `Tests/liquid-framesTests/MotionIntelligenceTests.swift` (Verification)

- Validates tuning range normalization.
- Validates gesture signal response behavior.
- Validates adaptive engine behavior for slow runs.
- Validates quality evaluator instability detection.
