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

## Agent Mode (Headless Reliability)

Use `--agent` for machine-driven checks with deterministic JSON output and policy exit codes.

```bash
swift run liquid-frames --agent check --pretty
swift run liquid-frames --agent check --min-runs 8 --require-grade A --require-quality healthy
swift run liquid-frames --agent benchmark --preset responsive --pretty
```

- Exit `0`: pass
- Exit `2`: policy failed
- Exit `64`: usage error

## Prototype Controls

- Drag upward on the parent window to gesture into branching.
- Use `Birth Two Branches` for button-triggered sequence.
- Use the top-right motion tuning panel for presets, auto-adapt, and deep parameter calibration.
- Drag speed and direction now deform branch curvature and split energy in real time.
- Birth rendering now includes deterministic inhale/exhale, aperture opening, neck pressure, and spit strength dynamics.
- Scene semantics now map to human-facing transitions (`voice -> chat`, toolchain spawn) with lineage tags.
- Parent window now follows a flower-like breath cycle and ejects two child windows from the top aperture.
- Parent now includes a recoil dip/recovery after ejection, and child launch spread is spit-strength-driven.
- Use the telemetry panel to inspect quality state, latest run phase timing, and run-history consistency.
- Use `Run Benchmark` to generate deterministic profile quality scores and scenario breakdowns.
- Use profile controls to create/duplicate/select/save/revert/delete named motion profiles.
- Edit active profile metadata (name, notes, comma-separated tags) before saving promotion-ready presets.
- Set per-profile benchmark baselines and inspect pass/warn/fail regression checks.
- Workspace state now persists automatically to `~/Library/Application Support/liquid-frames/motion-workspace.json`.
- Use telemetry actions to save, reload, export JSON snapshots, import latest desktop snapshot, and export release-gate markdown reports.
