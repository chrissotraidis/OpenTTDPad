# 09 — Autonomous Implementation Roadmap

Phases 0–5, every task with objective, work items, acceptance criteria, dependencies, risk, and effort. Gates G0–G5 close each phase; the go/no-go experiments EXP-1…EXP-10 are listed in §8 with their pass definitions. Execution rules (order, stop conditions, definition of done) are in [00-builder-instructions.md](00-builder-instructions.md).

Effort figures assume one experienced C++/Apple-platform engineer and are calibration, not commitments.

---

## Phase 0 — Feasibility spike (3–7 days total)

Prove the native build before any UX investment.

### P0.0 Fact re-verification — *0.5 day, risk: low*
Execute the verification table in [00-builder-instructions.md](00-builder-instructions.md) §3; create `docs/UPSTREAM_FACTS.md` and `docs/STATUS.md`.
**Accept:** every table row has a verified value, source URL, and date.

### P0.1 Upstream baseline on macOS — *0.5–1 day, risk: low*
Clone official OpenTTD; check out the current stable tag (15.3 at research time); build Release with CMake on Apple Silicon; run upstream's automated tests; launch and play.
**Accept:** clean Release build; free base sets load; a save is created and reopened.
**Deliverable:** exact commands recorded in `STATUS.md`; this tag becomes the subtree base (P0.2a).

### P0.2 iOS toolchain build — *1–3 days, risk: medium*
(a) Establish the repo layout of [08-repository-strategy.md](08-repository-strategy.md): subtree-add the baseline tag into `engine/`.
(b) Write `cmake/ios.toolchain.cmake`; implement the two-stage host-tools build ([07-build-and-ci.md](07-build-and-ci.md) §2); select the dependency strategy (BR-4) and build SDL2 + required deps static for arm64 iOS; exclude Cocoa/desktop-only sources from the iOS target; stub what must be stubbed, documenting every platform assumption encountered.
**Accept:** all engine objects compile and link for arm64 device; no x86 dependency; no JIT/dynamic-code requirement discovered (EXP-1).

### P0.3 SDL iOS first frame — *2–4 days, risk: medium*
Create the app target (minimal shell per [02-architecture.md](02-architecture.md) §2.1, scene-based); integrate SDL2 iOS main handling (ADR-007 Option A, falling back to Option B only with evidence); connect the engine entry point; bundle minimum free data; initialize writable sandbox paths (first cut of `ios_paths.cpp`).
**Accept (EXP-2, EXP-4, EXP-5):** app launches on Simulator **and** physical iPad; main menu renders and refreshes; app survives a rotation notification (orientation stays landscape); config + a save survive relaunch.
**Decision gate inside the task:** if this requires replacing major rendering or application-loop systems, stop and report per stop-condition rules.

### P0.4 Input probe — *1 day, risk: medium*
Instrument an event-log overlay/console. Exercise: one finger, two fingers, Pencil, trackpad, mouse, right-click, wheel, hardware keyboard, and a text field.
**Accept (EXP-6, EXP-7, EXP-8):** every input type appears in the log; synthetic touch-mouse events are distinguishable from physical pointer events (with the SDL hints of PK-2 validated); the software keyboard appears via SDL text input.

### GATE G0
**Pass ⇔ EXP-1…EXP-8 all pass** (EXP-3 provisionally: menu-screen smoothness; full check at G1) and the P0.3 decision gate did not trigger. Fail ⇒ architecture reset report; do not proceed.

---

## Phase 1 — Functional native build (8–15 days)

### P1.1 iPad platform directory — *complete `src/os/ios/`*
Sandbox data paths per [06-saves-lifecycle.md](06-saves-lifecycle.md) §2: personal, cache, config, save, screenshot, crash paths; atomic-write plumbing (SL-5).
**Accept:** T-FILE path tests pass; layout in Files app matches CO-16.

### P1.2 Lifecycle bridge
Implement SL-6…SL-11: active/inactive/background/foreground/terminate, memory warning, audio interruption; emergency autosave with `beginBackgroundTask`.
**Accept:** scripted lifecycle runs T-LIFE-1…-6 pass on device.

### P1.3 Rendering stability
Native (Retina) resolution; safe-area insets propagated; frame pacing sane; pause stops rendering; resize/rotation-notification handling safe.
**Accept:** T-REND set passes; zoomed screenshot pixel-checks confirm native scale.

### P1.4 Audio
SDL audio on device: effects + music, Bluetooth/AirPods, volume, interruption handling per SL-11; audio-session category decision recorded (ADR amendment, [02-architecture.md](02-architecture.md) §6).
**Accept:** T-AUD set passes on speaker + Bluetooth route.

### P1.5 Free content packaging
License audit (CO-3) then bundle graphics + sounds; music download deferred to P3.4 if size is material; in-app notices screen stub (CO-4).
**Accept:** clean first install reaches playable menu offline (FR-8); notices render.

### GATE G1
Install through Xcode → launch offline → create game → build a transport route **with a mouse** → save → background → return → reload save → sound and music play. All of FR-1, FR-2, FR-8 acceptance criteria demonstrated on hardware; EXP-3 (software-render smoothness in a real game) passes; EXP-9 (ten lifecycle cycles) passes.

---

## Phase 2 — Touch MVP (18–30 days)

Implements [03-touch-interaction.md](03-touch-interaction.md) in full.

| Task | Scope | Accept |
|---|---|---|
| P2.1 Touch event translator | `TouchInputTranslator` consuming SDL finger events; input router with source tagging (PK-2) | unit tests for state transitions (tests/touch) pass; taps activate UI |
| P2.2 Map panning | TI-5, TI-7, momentum (§5.3), pan sensitivity setting | T-TOUCH pan cases |
| P2.3 Pinch zoom | TI-6, §5.4 midpoint-anchored discrete stepping | T-TOUCH zoom cases; zoom stays under fingers |
| P2.4 Secondary interaction | TI-8 two-finger tap, TI-9 long-press routing | T-TOUCH secondary cases |
| P2.5 Tool-state gesture routing | TI-15…TI-19b; `SetToolContext` hooks; distinguish pan / rail drag / road drag / terrain drag / selection drag / window drag | T-TOUCH construction cases |
| P2.6 Expanded hit testing | TI-27 without visual distortion; touch-only | T-TOUCH hit-region cases |
| P2.7 Precision mode | TI-20…TI-24 loupe, snapping, cancel | FR-4 criterion (80% first-try success in trials) |
| P2.8 iPad defaults | TI-26 per-device presets, tuned constants committed back to doc 03 §6 | defaults reviewed on ≥ 3 device classes |

### GATE G2 (= FR-3 + EXP-10)
A touch-only user can: start a game, build roads, build tracks, place stations, create routes, buy vehicles, manage orders, alter terrain, zoom and pan, save and reload — **no keyboard or mouse attached**. EXP-10: a first-time tester builds a basic road **and** rail route without developer instruction. Failure of EXP-10 with a technically-green build ⇒ iterate within Phase 2; it blocks public release, not further engineering.

---

## Phase 3 — Productization (12–22 days)

| Task | Scope |
|---|---|
| P3.1 First-launch onboarding | CO-5…CO-7 native flow |
| P3.2 Save import/export | FR-7, CO-14…CO-16, Export All Saves (SL-4) |
| P3.3 Original TTD asset importer | CO-8…CO-11 (may slip post-1.0 by gate decision) |
| P3.4 Content downloader | FR-9, CO-12…CO-13; libcurl-vs-NSURLSession decision (BR-5) |
| P3.5 Settings interface | FR-11 + doc 03 §8 touch settings |
| P3.6 Crash & diagnostics export | SL-13, diagnostics bundle (CO exports) |
| P3.7 Build scripts | BR-7…BR-9 final |
| P3.8 CI | BR-10…BR-11 full matrix |
| P3.9 Documentation | README build guide, sideload guide, in-app notices complete (CO-4); international-text deps enabled (BR-5 FreeType/HarfBuzz/ICU) |

### GATE G3
A developer can clone → bootstrap → sign → install using only documented steps. A player can start a free game with no external assets and round-trip saves through Files (US-1 demonstrated). Hygiene CI green including forbidden-asset scan.

---

## Phase 4 — Desktop-quality input & advanced iPad support (12–25 days)

- P4.1 Keyboard completeness: validate every default hotkey; reserved-key audit + substitutes (PK-11…PK-13, PK-17)
- P4.2 Hover/tooltip parity and trackpad tuning (PK-6, PK-10)
- P4.3 Seamless input-mode switching polish (PK-18…PK-20)
- P4.4 Stage Manager resizing (drop `UIRequiresFullScreen`; surface-recreation path already proven) + external display support
- P4.5 Apple Pencil precision behavior (PK-21)
- P4.6 Optional iCloud saves **only if** SL-12 conflict design is approved; otherwise defer

### GATE G4
Full input matrix ([10-testing.md](10-testing.md) §3) passes; FR-5/FR-6 complete criteria met; Stage Manager and external display demos recorded.

---

## Phase 5 — Multiplayer and release (15–30 days)

- P5.1 Server discovery + direct connection + password entry (FR-12)
- P5.2 Chat; NewGRF synchronization on join
- P5.3 Disconnect/reconnect handling per MP-1…MP-6; network-transition lifecycle testing
- P5.4 Public beta (sideload + TestFlight-if-license-review-passes), feedback triage
- P5.5 License review + corresponding-source release automation (BR-12); IPA packaging
- P5.6 Conditional App Store submission ([11-licensing-distribution.md](11-licensing-distribution.md) §4) — explicitly **not** a 1.0 success criterion

### GATE G5 (public 1.0)
Success metrics for release in [13-metrics.md](13-metrics.md) all green.

---

## 8. Go/no-go experiments

| ID | Experiment | Pass definition | Phase |
|----|-----------|-----------------|-------|
| EXP-1 | Current stable compiles for iOS arm64 | core source compiles with current Xcode/Clang | P0.2 |
| EXP-2 | SDL creates a visible iPad window | main menu renders on physical hardware | P0.3 |
| EXP-3 | Software rendering fast enough | smooth viewport movement in a normal game, no sustained thermal issues | G1 |
| EXP-4 | Free content loads from bundle | first launch reaches playable menu, no downloads, no commercial assets | P0.3 |
| EXP-5 | Sandbox writes work | config and saves survive relaunch | P0.3 |
| EXP-6 | Physical pointer works | left-click, right-click, wheel, hover, drag via mouse + Magic Keyboard trackpad | P0.4 |
| EXP-7 | Touch separable from synthetic mouse | direct gestures produce no duplicate actions | P0.4 |
| EXP-8 | Software keyboard works | company names, save names, chat, other text fields accept input | P0.4 |
| EXP-9 | Background/resume robust | ten repeated cycles: no crash, no audio loss, no save corruption | G1 |
| EXP-10 | Touch construction usable | first-time tester builds a basic road and rail route without instruction | G2 |

**EXP-1…EXP-4 failing = technical no-go or architecture reset** (stop-condition report). **EXP-10 failing = not releasable to the public yet**, even if technically functional.
