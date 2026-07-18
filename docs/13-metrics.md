# 13 — Success Metrics

Exit criteria per milestone and how each is measured. Privacy constraint: no analytics by default (NFR-PRV-1) — metrics come from test sessions, opt-in beta feedback, and repository/CI signals, never silent telemetry.

## Alpha (post-G2)

| Metric | Bar | Measured by |
|--------|-----|-------------|
| Device coverage | installs and runs on ≥ 3 iPad classes | STATUS.md device log |
| Stability | ≥ 95% crash-free test sessions | tester session reports (session = launch→quit) |
| Game loop | full single-player loop works | T-GAME-1…-9 green |
| Save fidelity | import/export correct; zero known corruption | T-GAME-14, T-LIFE suite |
| Desktop input | mouse and keyboard operate correctly | G1/G4 input checks |

## Beta (post-G3/G4)

| Metric | Bar | Measured by |
|--------|-----|-------------|
| Touch usability | ≥ 70% of test users complete the basic transport-route task touch-only | doc 10 §8 protocol |
| Lifecycle | zero critical lifecycle bugs open | issue tracker triage |
| Licensing | zero critical base-content licensing defects | doc 11 audits |
| Multiplayer | joins compatible servers (once Phase 5 lands) | T-PERF-6 |
| Upstream process | merge process documented and repeated at least once | a completed `sync:` PR |

## Public release (G5)

| Metric | Bar |
|--------|-----|
| Reproducible public build | clean-clone → documented steps → identical artifact checksums |
| Corresponding source | complete, published, mapped to the binary (BR-12/13) |
| Licenses | all notices documented in-app and in-repo |
| Touch | stable controls; EXP-10 pass on record |
| Devices | all Required matrix rows tested |
| Community | responsive issue triage (first response within a stated SLO in README) |
| Provenance | upstream version clearly identified in-app |
