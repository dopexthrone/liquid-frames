# Professional Motion Workflow

This workflow is for teams that need repeatable, production-quality motion behavior rather than one-off visual tuning.

## 1) Start From A Preset

- `Balanced`: default baseline for product exploration.
- `Responsive`: lower latency and tighter spring response.
- `Cinematic`: slower and more expressive transitions for narrative demos.

Apply a preset first, then tune from there.

## 2) Run Calibration Loops

1. Run 5-10 interactions using realistic drag styles.
2. Watch the quality badge (`Healthy`, `Caution`, `Unstable`).
3. Run `Run Benchmark` to generate deterministic scenario scores.
4. Inspect latest run timing and recent-run consistency.
5. Check benchmark delta versus prior benchmark run.
6. Adjust one parameter group at a time:
   - initiation feel: `gestureThreshold`, `pullDistance`
   - split feel: `splitStiffness`, `splitDamping`
   - settle feel: `settleStiffness`, `settleDamping`
   - pacing: delay parameters

## 3) Use Auto-Adapt Intentionally

- Enable auto-adapt during early tuning sprints to converge faster.
- Disable auto-adapt when finalizing motion for a release candidate.
- Clear run history before comparing two candidate profiles.
- Clear benchmark history before benchmarking a new profile family.

## 4) Persist and Share Profiles

- Workspace auto-saves to:
  - `~/Library/Application Support/liquid-frames/motion-workspace.json`
- Use telemetry buttons for explicit lifecycle:
  - `Save`: force-write latest workspace state.
  - `Reload`: restore latest saved snapshot.
  - `Export JSON`: create timestamped snapshot for team review and build artifacts.
- Include exported JSON in PRs when motion profiles are updated.

## 5) Reliability Targets

- Stable end-to-end branch transition timing across repeated runs.
- No abrupt branch curvature jumps at high gesture velocity.
- Consistent trigger behavior across iMac and MacBook window sizes.
- Quality report should remain `Healthy` over repeated runs.
- Benchmark grade target: `A` or `B` for release candidates.
- Benchmark consistency score should remain high across iterations.

## 6) Engineering Verification

Run these checks before shipping changes:

```bash
swift build
swift test
```

Focus of test suite:

- parameter normalization invariants
- signal-estimation behavior
- adaptive behavior under slow timing
- quality instability detection
- deterministic benchmark scoring
- snapshot persistence roundtrip
