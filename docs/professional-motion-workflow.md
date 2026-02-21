# Professional Motion Workflow

This workflow is for teams that need repeatable, production-quality motion behavior rather than one-off visual tuning.

## 1) Start From A Preset

- `Balanced`: default baseline for product exploration.
- `Responsive`: lower latency and tighter spring response.
- `Cinematic`: slower and more expressive transitions for narrative demos.

Apply a preset first, then tune from there.

## 2) Create Named Profiles

- Create a profile per target experience (for example: `iMac-Prod`, `MacBook-Responsive`, `Demo-Cinematic`).
- Keep one active profile at a time and monitor the dirty flag.
- Save profile state after meaningful tuning changes.

## 3) Run Calibration Loops

1. Run 5-10 interactions using realistic drag styles.
2. Watch the quality badge (`Healthy`, `Caution`, `Unstable`).
3. Run `Run Benchmark` to generate deterministic scenario scores.
4. Inspect latest run timing and recent-run consistency.
5. Check benchmark delta versus prior benchmark run.
6. Watch live birth mechanics (`Neck %` and `Spit %`) to ensure inhale inflation precedes aperture opening and spit ejection.
7. Confirm the parent recoil pattern: slight post-spit drop followed by settle recovery.
8. Confirm visual semantics: children should emerge in a shared central lane, then bifurcate late during spit impulse.
9. Adjust one parameter group at a time:
   - initiation feel: `gestureThreshold`, `pullDistance`
   - split feel: `splitStiffness`, `splitDamping`
   - settle feel: `settleStiffness`, `settleDamping`
   - pacing: delay parameters

## 4) Use Auto-Adapt Intentionally

- Enable auto-adapt during early tuning sprints to converge faster.
- Disable auto-adapt when finalizing motion for a release candidate.
- Clear run history before comparing two candidate profiles.
- Clear benchmark history before benchmarking a new profile family.

## 5) Persist and Share Profiles

- Workspace auto-saves to:
  - `~/Library/Application Support/liquid-frames/motion-workspace.json`
- Use telemetry buttons for explicit lifecycle:
  - `Save`: force-write latest workspace state.
  - `Reload`: restore latest saved snapshot.
  - `Export JSON`: create timestamped snapshot for team review and build artifacts.
- `Import Latest`: merge the newest desktop JSON export into the current workspace.
- `Export Gate`: generate a markdown release-gate artifact for code review.
- Include exported JSON in PRs when motion profiles or baselines are updated.
- Keep profile metadata curated:
  - `name`: environment + intent (`iMac-Prod`, `MacBook-Responsive`)
  - `tags`: routing labels (`release`, `demo`, `latency`)
  - `notes`: reviewer context, assumptions, and risks

## 6) Reliability Targets

- Stable end-to-end branch transition timing across repeated runs.
- No abrupt branch curvature jumps at high gesture velocity.
- Consistent trigger behavior across iMac and MacBook window sizes.
- Quality report should remain `Healthy` over repeated runs.
- Benchmark grade target: `A` or `B` for release candidates.
- Benchmark consistency score should remain high across iterations.
- Regression target versus baseline:
  - release branch should remain `PASS`
  - `WARNING` requires review
  - `FAIL` blocks motion-profile promotion
- Release-gate markdown should avoid `BLOCKED` status before promotion.

## 7) Engineering Verification

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
- deterministic benchmark regression classification
- snapshot persistence roundtrip
- snapshot merge conflict resolution
- release-gate report status classification

## 8) Agent Reliability Gate

Use this when integrating with autonomous systems or CI/CD pipelines:

```bash
swift run liquid-frames --agent check --pretty
```

- The command emits JSON with gate status, quality, benchmark grade, and policy failure reasons.
- Exit code contract:
  - `0`: pass
  - `2`: policy failure
  - `64`: usage/configuration error
