# liquid-frames

Prototype playground for Apple-guideline-aligned liquid branching window dynamics.

Context was gathered on February 20, 2026 from official Apple sources and translated into implementation rules for a branching "window birth" interaction.

- Apple resources and links: `docs/apple-dev-kit-context-2026-02-20.md`
- Prototype behavior spec: `docs/liquid-birth-prototype-spec.md`
- Component architecture: `docs/component-breakdown.md`

## Run

```bash
swift build
swift run
```

## Prototype Controls

- Drag upward on the parent window to gesture into branching.
- Use `Birth Two Branches` for button-triggered sequence.
- Use the top-right motion tuning panel to calibrate spring/delay values live.
- Drag speed and direction now deform branch curvature and split energy in real time.
