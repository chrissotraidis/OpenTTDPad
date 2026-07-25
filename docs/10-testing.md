# 10 — Testing Plan

Device and input matrices, the test catalog with stable IDs, and the usability protocol behind EXP-10. Automated where practical (gesture state machine, paths, CI smoke); scripted-manual where the platform demands it (hardware input, lifecycle, thermal).

---

## 1. Test infrastructure

- **Unit (host-runnable):** `engine/src/tests/gesture_state.cpp` — gesture state
  machine fed synthetic event streams, asserting emitted actions (tap vs drag
  vs pinch vs long-press), settings changes, 44 pt hit expansion, edge cases,
  cancellation, two-finger momentum, strict one-finger suppression after
  movement or a finger-count transition, and source
  separation. Runs in macOS CI on every PR.
- **Integration:** `tests/file_import/` — sandbox path resolution, atomic-save crash simulation (kill between temp-write and rename ⇒ old file intact), import/export round-trips.
- **On-device scripted-manual:** checklists below, executed per phase gate and per release candidate; results (video/log links) recorded in `docs/STATUS.md`.
- **CI smoke:** Simulator boot + launch + first-frame assertion (BR-10).

Current automated Simulator coverage is seven native XCTest scenarios on iPad
Pro 13-inch, base iPad, and iPad mini: first-run coaching; visible one-finger
cursor, map-pan suppression, and precision hold; exact Rail palette, Autorail construction drag, and
Cancel; exact Road palette, Autoroad construction drag, and Cancel; lifecycle
background/foreground recovery; touch settings, left/right control placement,
menu toggle behavior, formatted licenses; and ZIP save
export. The 2026-07-24 matrix passed **21/21**. Result-bundle paths and the
hardware-only limits of that evidence are recorded in `STATUS.md`.
The runner boots and installs `build/ios-sim/openttd.app` before every suite,
and the UI assertions cover the coach, compact persistent options control, and
active-tool Cancel controls.

## 2. Device matrix

| Device | Priority |
|---|---|
| 11-inch iPad Pro | Required |
| 13-inch iPad Pro | Required |
| Current base iPad | Required |
| iPad Air | Required |
| iPad mini | Required |
| iOS Simulator | Required (CI) |
| Older supported iPad (min-OS device) | Recommended |
| External display | Phase 4 |

Release candidates must pass the Required rows; day-to-day development may use any subset.

## 3. Input matrix

Touch only · Magic Keyboard (keys + trackpad) · Bluetooth mouse · Bluetooth keyboard + mouse · USB mouse · Apple Pencil · mixed touch + mouse in one session · software keyboard. Each cell = the core-gameplay smoke list (§4) at G4; basics (click/scroll/type) at G1.

## 4. Core gameplay tests (T-GAME)

Run touch-only **and** pointer+keyboard at applicable gates.

| ID | Test |
|----|------|
| T-GAME-1 | New game via map generation (small, default, 1024×1024) |
| T-GAME-2 | Roads: build, bridge, tunnel; demolish |
| T-GAME-3 | Rail: track, signals (precision mode), depot, station; full working route with two trains |
| T-GAME-4 | Stations: bus, truck, rail, airport, dock |
| T-GAME-5 | Terrain: raise/lower/level; clear |
| T-GAME-6 | Vehicles: buy, orders (multi-stop), clone, replace, sell |
| T-GAME-7 | Windows: open/drag/close finances, industry, town, graphs, company |
| T-GAME-8 | Settings: change + persist across relaunch (FR-11) |
| T-GAME-9 | Save/load: manual, autosave, overwrite; names with non-ASCII text |
| T-GAME-10 | Screenshot: normal + giant (memory-safe, CO-14a) |
| T-GAME-11 | Scenario: load `.scn`, play |
| T-GAME-12 | NewGRF: download in-app, activate, new game (FR-9) |
| T-GAME-13 | AI + Game Script: install, run a full session |
| T-GAME-14 | Desktop round-trip: desktop save → iPad → play → export → desktop loads (US-1) |

## 5. Lifecycle tests (T-LIFE)

| ID | Test |
|----|------|
| T-LIFE-1 | Lock device mid-game → unlock: paused, intact |
| T-LIFE-2 | Background 5 s → return: auto-resume per RESUME_GRACE_MS rule |
| T-LIFE-3 | Background several minutes → return: paused, emergency autosave exists |
| T-LIFE-4 | Memory pressure (Simulator warning / memory hog on device): no crash, caches trimmed |
| T-LIFE-5 | Audio interruption (timer/call) mid-game: pause, clean resume |
| T-LIFE-6 | Keyboard and mouse disconnect mid-drag: no stuck state (PK-20) |
| T-LIFE-7 | Network loss during content download: recoverable (NFR-REL-3) |
| T-LIFE-8 | Low storage: save attempt errors clearly, no truncation (NFR-REL-2) |
| T-LIFE-9 | App update (install new build over old): saves and settings intact |
| T-LIFE-10 | OS-kill while backgrounded → relaunch: emergency-autosave recovery offer (SL-9) |
| T-LIFE-11 | EXP-9 loop: 10× background/foreground cycles, then full T-GAME-9 |
| T-LIFE-12 | Rotation notification (landscape flip) mid-construction: seamless |

## 6. Rendering/audio spot checks (T-REND / T-AUD)

T-REND-1 native-scale pixel check (screenshot vs screen dimensions) · T-REND-2 safe-area: no interactive element clipped by corners/home indicator on every required device · T-REND-3 pause = zero rendering CPU (Instruments) · T-AUD-1 effects + music on speaker · T-AUD-2 AirPods route change mid-game · T-AUD-3 volume/silent behavior matches chosen session category.

## 7. Performance tests (T-PERF)

| ID | Test | Bound |
|----|------|-------|
| T-PERF-1 | Default map, 60-min session, oldest required device | NFR-PERF-1/2/4: tick rate, pan smoothness, no sustained throttling |
| T-PERF-2 | 1024×1024, 500+ vehicles | NFR-PERF-6: interactive |
| T-PERF-3 | Multiple AI companies + heavy NewGRF set | playable; document config used |
| T-PERF-4 | Touch latency measurement (240fps camera or instrumented timestamps) | NFR-PERF-3: ≤ 100 ms |
| T-PERF-5 | Background/paused CPU | NFR-PERF-5: ~0% |
| T-PERF-6 | Multiplayer session 30 min (Phase 5) | stable, no desync |

## 8. Usability protocol (EXP-10 / FR-4)

Participants: ≥ 5 per round, mix of OpenTTD-experienced and new players; no developer coaching. Script: "Connect these two towns by road with a bus route; then build a two-station rail line with a train." Measure: task completion without instruction; first-try success rate for precision targets (FR-4's 80% bar); think-aloud confusion points. Each round's tuned constants and findings are committed to doc 03 §6 and `STATUS.md`. Beta bar ([13-metrics.md](13-metrics.md)): ≥ 70% of test users complete the basic transport-route task with touch alone.
