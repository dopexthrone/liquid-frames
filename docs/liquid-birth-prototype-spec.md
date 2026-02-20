# Liquid Birth Prototype Spec (v0)

Goal: Prototype a parent glass window that opens and "gives birth" to two child windows using Apple-aligned liquid motion and hierarchy rules.

## Experience Target

- Platform focus: macOS Tahoe 26 on iMac/MacBook first, then iPadOS 26.
- Visual language: Apple Liquid Glass for control and window chrome behavior.
- Narrative: one parent context branches into two child contexts while preserving continuity.

## Interaction Sequence

1. Parent window appears as a floating glass pane with clear content focus.
2. User triggers branch action from a primary glass control in the parent pane.
3. Parent pane stretches along a single axis, then bifurcates into two child panes.
4. Children separate with spring motion and settle into a non-overlapping layout.
5. Child panes retain a visible lineage from parent state (title/context token transfer).

## Apple-Guideline Constraints (Must Pass)

- Use Liquid Glass for controls/chrome, not as a decorative global filter.
- Keep each pane's control cluster inside a single glass family.
- Avoid glass-on-glass overlap between unrelated panes.
- Preserve hierarchy with consistent spacing, corner radii, and concentric structure.
- Keep labels regular-weight and avoid custom tinting of primary nav surfaces.
- Let content flow behind chrome where appropriate; do not force opaque bars.
- Prefer one dominant scroll region per pane.

## Motion and Material Rules

- Motion profile: fluid and spring-based, with light snap at settle.
- Suggested spring baseline for branch settle: damping around `0.7` (Apple session guidance).
- Include tactile feedback at split completion and at child settle checkpoints.
- Use adaptive blur/refraction behavior so glass remains legible over changing content.

## SwiftUI Implementation Shape

- Keep parent + child related glass controls in `GlassEffectContainer`.
- Use shared and changing `glassEffectID` values for continuity across split states.
- Use `safeAreaInset` for floating controls, not overlay-heavy ad hoc placement.
- Use `backgroundExtensionEffect` when panes scroll and chrome needs continuity.

## State Model (Prototype-Level)

- `idle`: parent only
- `gesturing`: parent stretching and preparing split
- `splitting`: parent-to-child topological transition
- `settling`: children spring to final positions
- `branched`: stable two-child layout

## Success Criteria for Demo

- Transition communicates continuity, not teleportation.
- Child panes feel system-native on macOS (material, motion, spacing, typography).
- Interaction remains readable at iMac and MacBook window sizes.
- All visible chrome behavior aligns with Apple Liquid Glass guidance.
