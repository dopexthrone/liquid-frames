# liquid-frames

Prototype playground for Apple-guideline-aligned liquid branching window dynamics.

Context was gathered on February 20, 2026 from official Apple sources and translated into implementation rules for a branching "window birth" interaction.

- Apple resources and links: `docs/apple-dev-kit-context-2026-02-20.md`
- Prototype behavior spec: `docs/liquid-birth-prototype-spec.md`
- Component architecture: `docs/component-breakdown.md`
- Professional tuning workflow: `docs/professional-motion-workflow.md`

## Run

```bash
swift build
swift run
swift test
```

## Prototype Controls

- Drag upward on the parent window to gesture into branching.
- Use `Birth Two Branches` for button-triggered sequence.
- Use the top-right motion tuning panel for presets, auto-adapt, and deep parameter calibration.
- Drag speed and direction now deform branch curvature and split energy in real time.
- Use the telemetry panel to inspect quality state, latest run phase timing, and run-history consistency.
- Use `Run Benchmark` to generate deterministic profile quality scores and scenario breakdowns.
- Workspace state now persists automatically to `~/Library/Application Support/liquid-frames/motion-workspace.json`.
- Use telemetry actions to save, reload, or export workspace snapshots as JSON.
