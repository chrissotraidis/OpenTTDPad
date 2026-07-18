# 01 — Product Requirements

The master requirements document. Detailed interaction, technical, and process specs live in docs 02–11; this document defines *what* the product is and the binding functional and non-functional requirements.

---

## 1. Vision

Create the definitive native OpenTTD experience for iPadOS.

The application must feel appropriate on a tablet rather than like a desktop program remotely controlled through finger-based mouse emulation. It must support three equally legitimate input configurations with instantaneous switching between them:

1. Touch only
2. Magic Keyboard or external keyboard with trackpad or mouse
3. Mixed touch and pointer input

**Product statement:**

> OpenTTD for iPadOS is a native, open-source iPad adaptation of the current upstream OpenTTD engine, providing touch-first controls, desktop-quality pointer input, compatible saves, online content, and straightforward installation.

## 2. What this project is / is not

**Is:** a native iPadOS platform port; an iPad interaction and usability layer; an upstream-tracking OpenTTD distribution; a packaging, lifecycle, input, and Apple-platform integration project.

**Is not:** a recreation of the OpenTTD engine; an emulated Windows build; a browser wrapper; an unofficial repackaging with ads; a Transport Tycoon Deluxe asset bundle; a major redesign of OpenTTD's simulation; an attempt to replace the upstream project.

**Public positioning.** The correct public claim is: *"A native, touch-first iPadOS port of the current OpenTTD engine."* The project shall not claim: to be the first OpenTTD on iPad; to be an official upstream release; to include Transport Tycoon Deluxe; to have invented the engine; or to have solved touch interaction before usability testing proves it.

## 3. Goals

### Primary goals (1.0)
| # | Goal |
|---|------|
| PG-1 | Compile the current upstream OpenTTD engine for physical arm64 iPads |
| PG-2 | Launch a playable game using freely distributable base graphics and sounds |
| PG-3 | Provide direct, understandable touch interaction |
| PG-4 | Preserve desktop mouse, trackpad, and keyboard behavior |
| PG-5 | Support desktop-compatible save importing and exporting |
| PG-6 | Support normal OpenTTD online content where legally and technically appropriate |
| PG-7 | Pause and resume reliably through the iPadOS lifecycle |
| PG-8 | Provide a repeatable Xcode and command-line build |
| PG-9 | Minimize the downstream patch set |
| PG-10 | Publish all corresponding source and required notices |

### Secondary goals (post-1.0, in rough priority order)
iCloud save synchronization · Stage Manager resizing · external displays · Apple Pencil precision input · multiplayer · original Transport Tycoon Deluxe asset importing (may land in 1.0 if Phase 3 schedule permits) · App Store distribution.

## 4. Non-goals for version 1.0

- Portrait orientation
- Simultaneous multiple game windows
- Controller-first operation
- Complete redesign of every OpenTTD window
- Compatibility guarantees for every NewGRF before release
- Bundled original Transport Tycoon Deluxe files
- New gameplay mechanics
- Guaranteed App Store availability

Non-goals are scope fences, not judgments; several are Phase 4/5 or post-1.0 items.

## 5. Target users

**Primary:** existing OpenTTD players who own an iPad; Transport Tycoon Deluxe players seeking a modern portable version; simulation players who prefer tablets; Magic Keyboard users who want desktop-like gameplay on iPad; players who move saves between computers and iPads.

**Secondary:** casual players discovering OpenTTD for the first time; NewGRF and scenario creators; multiplayer users; educators and transport-planning enthusiasts.

**Representative user stories** (used for usability test scripts in [10-testing.md](10-testing.md)):

- US-1: As a desktop OpenTTD veteran, I import my 500-hour desktop save through Files and continue it on the couch, then export it back with no loss.
- US-2: As a first-time player on a base iPad, I launch the app, accept the free content, and build my first bus route with only my fingers, without reading a manual.
- US-3: As a Magic Keyboard user, I play exactly as on desktop: right-click, scroll wheel, hotkeys, hover tooltips.
- US-4: As a commuter, I lock my iPad mid-game; hours later the game resumes paused exactly where I left it.
- US-5: As a NewGRF enthusiast, I download content in-app and start a game with it.

## 6. Functional requirements

Each FR is binding for the release milestone noted. Acceptance criteria are testable as written; the test catalog maps them to test IDs.

### FR-1: Native startup — *Phase 1*
The application shall launch the native OpenTTD engine on a physical arm64 iPad without browser or Windows emulation.

**Acceptance criteria:** main menu displays; free graphics load; sound initializes; no missing-file error on first launch; no private API usage; no JIT or dynamic-code-generation dependency.

### FR-2: New game — *Phase 1*
The player shall be able to create and play a new single-player game.

**Acceptance criteria:** map generation succeeds (at least 256×256 through 1024×1024); simulation advances in real time; company creation works; vehicles can be purchased and operated; save and load work.

### FR-3: Direct touch — *Phase 2*
The application shall support all core gameplay through touch alone, per the full spec in [03-touch-interaction.md](03-touch-interaction.md).

**Acceptance criteria (touch-only, no pointer or keyboard attached):** build road; build rail; place stations; place depots; alter terrain; pan; zoom; open, drag, and close windows; manage vehicles and orders; navigate all menus; save and load.

### FR-4: Precision interaction — *Phase 2*
The player shall have a method to select individual tiles and small controls accurately (precision mode, TI-20…TI-24).

**Acceptance criteria:** a signal can be placed on a specific track piece, and a bridge endpoint selected on the intended tile, on the first attempt in ≥ 80% of usability-test trials.

### FR-5: Pointer input — *Phase 1 (basic) / Phase 4 (complete)*
Mouse and trackpad shall preserve normal desktop semantics per [04-pointer-keyboard.md](04-pointer-keyboard.md).

**Acceptance criteria:** left/right/middle click, precise two-axis scrolling, click-drag construction, hover tooltips, cursor visibility, edge scrolling, desktop-style window dragging.

### FR-6: Keyboard input — *Phase 1 (basic) / Phase 4 (complete)*
Hardware keyboard shortcuts and text entry shall function, including modifiers (Ctrl, Shift, Option/Alt, Cmd where useful), arrows, Escape, and OpenTTD's configurable hotkeys.

**Acceptance criteria:** every shortcut in upstream's default `hotkeys.cfg` either works or has a documented iPad-reserved-key substitute; text entry works in every OpenTTD text field via hardware and software keyboards.

### FR-7: Files — *Phase 3*
The player shall be able to import and export saves (and the other formats in [05-content-onboarding.md](05-content-onboarding.md) §6) through the Files app, using native document pickers and share sheets.

**Acceptance criteria:** a desktop-created `.sav` imports and loads; an iPad-created save exports and loads on desktop OpenTTD of the same or newer version; saves survive app updates; an "Export All Saves" command exists.

### FR-8: Base content — *Phase 1*
The application shall install or obtain a complete freely playable base configuration (graphics + sounds mandatory; music optional download) without user-supplied files.

**Acceptance criteria:** first launch reaches a playable main menu offline; all bundled-content licenses and notices are displayed in-app.

### FR-9: Online content — *Phase 3*
The player shall be able to retrieve supported online OpenTTD content (NewGRFs, scenarios, heightmaps, AIs, Game Scripts, base sets) through the in-game content system, stored in the app's writable support directory.

**Acceptance criteria:** content list loads; a NewGRF downloads and activates in a new game; content persists across relaunch.

### FR-10: Lifecycle — *Phase 1 (core) / Phase 3 (hardened)*
The application shall survive backgrounding, device locking, and audio interruptions without losing saves or crashing, per [06-saves-lifecycle.md](06-saves-lifecycle.md).

**Acceptance criteria:** ten consecutive background/foreground cycles with no crash, no audio loss, no save corruption (EXP-9); single-player auto-pauses on resign-active; an emergency autosave exists after every backgrounding.

### FR-11: Settings — *Phase 3*
The application shall persist touch, display, sound, and gameplay settings across launches, including every touch-specific setting in [03-touch-interaction.md](03-touch-interaction.md) §8.

### FR-12: Multiplayer — *Phase 5*
The application shall support joining compatible multiplayer servers: server discovery, direct connection by address, password entry, compatible-NewGRF download, chat, save synchronization, graceful disconnect handling (MP-1…MP-7 in [06-saves-lifecycle.md](06-saves-lifecycle.md) §7).

**Acceptance criteria:** joins a current-version public server and plays ≥ 30 minutes; backgrounding produces a clean disconnect-and-report, never a corrupted state.

## 7. Non-functional requirements

### Performance
| ID | Requirement | Target / measure |
|----|-------------|------------------|
| NFR-PERF-1 | Responsive simulation on supported iPads | default 256×256 map, ≥ 30 simulated ticks/s sustained on the oldest supported device |
| NFR-PERF-2 | Smooth viewport panning | no visible stutter at default zoom; frame pacing consistent during pan on all required devices |
| NFR-PERF-3 | Touch latency | ≤ 100 ms from finger-down to visible response for taps on UI controls |
| NFR-PERF-4 | Thermal behavior | no sustained thermal throttling during a 60-minute session on a normal map |
| NFR-PERF-5 | Battery while paused | app in background or paused uses no measurable CPU (verified with Instruments) |
| NFR-PERF-6 | Large maps | 1024×1024 with 500+ vehicles remains playable (may run below full tick rate but must stay interactive) |

### Reliability
| ID | Requirement |
|----|-------------|
| NFR-REL-1 | No save corruption under any lifecycle event; save writes are atomic (write-temp-then-rename) |
| NFR-REL-2 | Out-of-storage conditions produce a clear error, never a truncated save |
| NFR-REL-3 | Content-download failures are recoverable and resumable |
| NFR-REL-4 | Backgrounding during any operation (saving, generating, downloading) is safe |
| NFR-REL-5 | Deterministic simulation identical to upstream: same seed + same inputs ⇒ same state (required for multiplayer and desktop save parity) |

### Maintainability
| ID | Requirement |
|----|-------------|
| NFR-MNT-1 | Small, isolated iPad patch set; every upstream-file edit logged in `PATCHES.md` |
| NFR-MNT-2 | The exact upstream base commit/tag is recorded and mechanically checkable (`UPSTREAM_VERSION.md`) |
| NFR-MNT-3 | Automated build validation on every PR (see [07-build-and-ci.md](07-build-and-ci.md)) |
| NFR-MNT-4 | No dependency on abandoned iOS forks or unmaintained third-party layers |

### Privacy
| ID | Requirement |
|----|-------------|
| NFR-PRV-1 | No analytics by default; no advertising ever |
| NFR-PRV-2 | No account system beyond what OpenTTD multiplayer itself requires |
| NFR-PRV-3 | Network access only for user-requested content downloads and multiplayer |
| NFR-PRV-4 | Crash-report behavior disclosed in-app; crash exports are user-initiated |

### Accessibility (initial)
| ID | Requirement |
|----|-------------|
| NFR-ACC-1 | Adjustable GUI scale independent of world zoom ([03-touch-interaction.md](03-touch-interaction.md) §7) |
| NFR-ACC-2 | Enlarged touch targets option |
| NFR-ACC-3 | Remappable gestures (long-press duration, two-finger tap toggle) |
| NFR-ACC-4 | Full keyboard operation of everything keyboard-operable on desktop |
| NFR-ACC-5 | High-contrast pointer option |
| NFR-ACC-6 | Configurable long-press timing (300–800 ms) |
| NFR-ACC-7 | No action available *solely* through a difficult gesture — every gesture action has a button, menu, or keyboard path |

## 8. Platform requirements

| Item | Requirement |
|------|-------------|
| Devices | arm64 iPads capable of running the chosen minimum iPadOS (see below) |
| Minimum OS | Propose iPadOS 17.0; builder confirms at P0.0 against SDK and SDL support, records in `UPSTREAM_FACTS.md` |
| SDK | Build with the current iOS/iPadOS SDK; scene-based lifecycle from day one (iOS/iPadOS 27 SDK will require it) |
| Orientation | Landscape only in 1.0 (both landscape directions) |
| Architecture | arm64 device + arm64 Simulator; no x86 requirement |
| Forbidden | Private APIs, JIT/dynamic code generation, embedded browser rendering for gameplay |

## 9. Feasibility context (informative)

Scores from the research snapshot, retained as planning context: engine portability 9/10, first native frame 8/10, touch usability 7/10 (the real product risk — see R-02), mouse/keyboard 9/10, assets 9/10, save compatibility 10/10, multiplayer 8/10, legal outside App Store 8/10, App Store 5/10, maintenance 7/10, community 8/10, originality 6/10.

Effort envelope (one experienced C++/Apple engineer): spike 3–7 days; first playable device build 10–20; touch-usable MVP 35–60; polished public beta 70–120; App Store-quality release 100–170 engineer-days. Excludes prolonged App Store disputes, deep upstream refactoring, and advanced multiplayer debugging.

Prior art (research material only, never foundations): an obsolete early-iOS native port; an Android fork with >1M installs whose reviews repeatedly fault the *controls* — the strongest available warning that running the game is not the same as making it usable; WebAssembly wrappers with missing sound and proxy-bound multiplayer.
