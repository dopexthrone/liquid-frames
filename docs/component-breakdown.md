# Component Breakdown

## 1) `LiquidFramesApp` (App Shell)

- Entry point and desktop window container.
- Owns scene lifecycle and minimum prototype window size.

## 2) `PrototypeRootView` (Composition Layer)

- Builds the full stage with:
  - atmospheric background
  - parent pane
  - child panes
  - birth-canal + late bifurcation connection strokes
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
- Manages profile library state, metadata drafts, active-profile dirty tracking, baselines, and regression checks.
- Merges imported desktop snapshots and emits release-gate reports for engineering handoff.

## 4) `MotionIntelligence` (Core Motion Domain Layer)

- Defines `MotionTuning`, validated ranges, and normalization.
- Provides developer presets via `MotionPreset` (`Balanced`, `Responsive`, `Cinematic`).
- Implements `GestureSignalEstimator` so gesture parsing is deterministic and testable.
- Implements `BirthDynamicsEngine` for deterministic inhale/exhale, aperture, neck, and spit-state synthesis.
- Implements `MotionQualityEvaluator` for reliability scoring.
- Implements `MotionAdaptiveEngine` for continuously self-improving profile adjustments.
- Implements snapshot models for persistence/export and benchmark models for deterministic scoring.
- Implements benchmark baseline + regression evaluator (`pass`/`warning`/`fail`) for profile-level quality gates.

## 5) `MotionStorage` (Workspace Persistence)

- Saves and loads workspace snapshots as JSON.
- Uses default location: `~/Library/Application Support/liquid-frames/motion-workspace.json`.
- Supports explicit export snapshots, import of latest desktop export, and release-gate markdown artifacts.

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

- Draws a single central throat/canal that bifurcates late into two child paths.
- Uses progressive trim and glow-stroke styling to sell “birth” continuity.
- Deforms branch curvature, membrane sheath, and umbilical neck tension from velocity, bias, and split/settle progress.

## 9) `SpitBurstLayer` (Ejection Particles)

- Emits breath halo + central jet + spit droplets from the top aperture toward children.
- Reacts to inhale/exhale/aperture/spit state from `BirthDynamicsEngine`.
- Keeps particles coalesced in one lane first, then splits trajectories late to avoid DAG-like visuals.

## 10) `ControlDeck` (Interaction Controls)

- Primary action toggles between branch and reset.
- Replay action re-runs the full sequence.
- Surfaces current phase, live drag threshold progress, and current quality state.

## 11) `MotionTuningPanel` (Live Calibration)

- Exposes named profile controls plus presets, auto-adapt toggle, spring/delay values, and gesture shaping values.
- Exposes profile metadata editing (`name`, `notes`, `tags`) with dirty-state tracking.
- Enables rapid calibration of "birth" feel during demo iteration.

## 12) `MotionTelemetryPanel` (Reliability Feedback)

- Displays quality report with warnings from the evaluator.
- Displays latest run phase timing breakdown and recent-run summary rows.
- Displays deterministic benchmark report/grade and benchmark deltas.
- Displays baseline regression status and profile-level benchmark deltas.
- Supports run/benchmark clearing, workspace save/reload/import/export controls, and release-gate export.

## 13) `Tests/liquid-framesTests/MotionIntelligenceTests.swift` (Verification)

- Validates tuning range normalization.
- Validates gesture signal response behavior.
- Validates adaptive engine behavior for slow runs.
- Validates quality evaluator instability detection.
- Validates benchmark determinism for fixed profiles.
- Validates workspace snapshot save/load roundtrip.
- Validates workspace merge behavior for deterministic profile/history outcomes.
- Validates deterministic birth-dynamics behavior and split/settle response.

## 14) `AgentCommandLine` (System Integration Surface)

- Exposes headless `--agent` commands for non-UI automation.
- Emits machine-readable JSON payloads for benchmark and reliability checks.
- Enforces policy thresholds (gate status, benchmark grade, quality level, run count) with explicit exit codes.
