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
- Coordinates timing and spring choreography for the branch sequence.

## 4) `PrototypeLayout` (Adaptive Layout Engine)

- Converts window size + motion progress into:
  - pane sizes
  - pane centers
  - anchor points for branch lines
  - opacity/scale transforms
- Keeps the motion legible across iMac and MacBook-style aspect ratios.

## 5) `LiquidPane` (Glass Card Primitive)

- Shared pane UI primitive for parent/children.
- Uses material-backed surfaces, soft highlight gradients, and open-top stroke option.
- Encodes readable information density without breaking visual hierarchy.

## 6) `BirthConnectionLayer` (Liquid Branch Strokes)

- Draws two curved paths that emerge from the parent and connect to children.
- Uses progressive trim and glow-stroke styling to sell “birth” continuity.

## 7) `ControlDeck` (Interaction Controls)

- Primary action toggles between branch and reset.
- Replay action re-runs the full sequence.
- Surfaces current phase and live drag threshold progress.

## 8) `MotionTuningPanel` (Live Calibration)

- Exposes spring stiffness/damping and phase delay values.
- Exposes gesture threshold and pull distance normalization.
- Enables rapid calibration of "birth" feel during demo iteration.
