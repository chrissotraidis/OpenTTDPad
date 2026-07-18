# 02 — Technical Architecture

How the port is structured: layers, ownership, threading, rendering, input pipeline, and the architecture decision records (ADRs) that fix the load-bearing choices.

---

## 1. Layer diagram

```text
┌───────────────────────────────────────────────┐
│ Native iPadOS shell (Swift / Objective-C++)   │
│  UIApplicationDelegate · UISceneDelegate      │
│  Document pickers · Share sheets              │
│  Safe-area metrics · Files & iCloud           │
│  Onboarding UI · Settings host UI             │
└──────────────────────┬────────────────────────┘
                       │  OpenTTDBridge (Obj-C++)
┌──────────────────────▼────────────────────────┐
│ iPadOS platform adapter (C++)                 │
│  Sandbox paths · Lifecycle callbacks          │
│  Keyboard bridge · Pointer/touch normalization│
│  Audio-session coordination                   │
└──────────────────────┬────────────────────────┘
                       │
┌──────────────────────▼────────────────────────┐
│ SDL2 iOS layer                                │
│  Window & rendering surface · Audio           │
│  Mouse/trackpad events · Keyboard events      │
│  Touch (finger) events · Text input           │
└──────────────────────┬────────────────────────┘
                       │
┌──────────────────────▼────────────────────────┐
│ OpenTTD engine (upstream, minimally patched)  │
│  Simulation · GUI · Networking · Saves        │
│  Content system · NewGRFs · Scripts · AI      │
└───────────────────────────────────────────────┘
```

Dependency rule: arrows point down only. The engine never includes UIKit headers; the shell never reaches into engine internals except through `OpenTTDBridge`.

## 2. Component responsibilities

### 2.1 Native shell (`os/ios/`, Swift + Obj-C++)

Owns everything that must be Apple-native:

- `AppDelegate.swift` — process-level events, SDL bootstrap handoff
- `SceneDelegate.swift` — scene lifecycle (one scene in 1.0, but scene-based from day one; iOS/iPadOS 27 SDK will require it)
- `OpenTTDBridge.mm` — the single Obj-C++ translation unit that calls into engine C++ (start, pause, resume, save-now, open-file, metrics push)
- `DocumentManager.swift` — `UIDocumentPickerViewController` import/export, share sheets, security-scoped resource handling
- `AudioSessionManager.swift` — `AVAudioSession` category/activation, interruption and route-change notifications forwarded to the adapter
- `OnboardingViewController.swift` — first-launch flow ([05-content-onboarding.md](05-content-onboarding.md) §2), shown before SDL takes the screen
- `Info.plist` — see §7

The shell owns the *decision* to start the engine; the engine never owns the shell.

### 2.2 iPadOS platform adapter (`src/os/ios/` inside the engine tree)

Pure C++ (Obj-C++ only where an Apple API forces it), mirroring upstream's per-OS layout (`src/os/macosx/`, `src/os/windows/`):

- `ios_paths.cpp` — implements OpenTTD's personal/config/cache directory resolution for the sandbox ([06-saves-lifecycle.md](06-saves-lifecycle.md) §2)
- `ios_lifecycle.cpp` — receives shell lifecycle callbacks; pauses simulation, triggers emergency autosave, suspends/resumes audio
- `ios_survey.cpp` / stubs — any upstream per-OS hooks that need an iOS answer (crash logging, hardware description)

### 2.3 Touch layer (`src/touch/`)

Platform-neutral gesture translation ([03-touch-interaction.md](03-touch-interaction.md)); designed so generic parts are upstreamable:

- `touch_input.cpp/.hpp` — `TouchInputTranslator`: consumes SDL finger events, emits OpenTTD-native input (pointer moves, clicks, drags, wheel/zoom, secondary click)
- `gesture_state.cpp/.hpp` — the gesture state machine (§5 of doc 03)
- `precision_mode.cpp/.hpp` — magnifier/cursor precision interaction
- `touch_settings.cpp/.hpp` — tunable constants + settings persistence glue

### 2.4 SDL2 layer

Upstream's `sdl2_v.cpp` / `sdl2_default_v.cpp` already provide: mouse motion and buttons, two-axis wheel with precise values, keyboard events, `SDL_StartTextInput`/`SDL_StopTextInput`, window resize, display discovery, fullscreen, cursor management. Upstream does **not** handle `SDL_FINGERDOWN/UP/MOTION` — that is exactly the gap `TouchInputTranslator` fills. Prefer subclass-or-sibling driver (`video/ios_v.cpp` deriving from the SDL2 driver) over editing `sdl2_v.cpp` in place, to keep the patch set isolated.

## 3. Main loop and threading

Upstream's non-web SDL build runs a conventional continuous loop and can run the game on a separate thread; the emscripten build proves the engine also works with a host-driven, callback-style loop.

**Requirement (P0.3 must decide):** choose the *least invasive SDL-supported* option:

1. **Option A (default):** SDL's standard iOS main integration (`SDL_main` rename, SDL-owned `UIApplicationMain`), engine loop unchanged. SDL provides an iOS animation-callback mechanism if the OS requires the app to return to the runloop.
2. **Option B (fallback):** expose `LoopOnce()` and drive it from a `CADisplayLink`-style host callback, mirroring the emscripten pattern.

Constraints either way:

- UIKit work stays on the main thread; if the game thread is separate, all shell→engine calls go through a thread-safe command queue in `OpenTTDBridge`.
- The loop must fully stop (not just skip frames) when backgrounded — iOS suspends the process; a wedged in-flight frame on suspension is a crash risk (SL-7).
- Frame pacing targets the display's refresh rate; the engine's own tick rate is untouched (prime directive 3).

## 4. Rendering

**Initial renderer: SDL2 default (software framebuffer) path.** Rationale: it exists upstream; avoids writing a Metal renderer; sufficient for OpenTTD's workload; SDL's iOS backend presents via Apple-supported APIs; minimizes rendering-logic changes. Upstream's driver already creates a resizable window, keeps a backing store, and reallocates the game surface on size change — which is what Stage Manager will need later.

**Explicitly avoided in v1:** direct desktop OpenGL, custom Metal renderer, ANGLE, WebGL, embedded browser rendering. A Metal path may be *considered* post-1.0 only if profiling shows measurable performance or battery problems (NFR-PERF-*).

Rendering requirements:

- Render at native scale (respect `UIScreen.scale` / SDL's high-DPI flag); no blurry non-Retina upscaling.
- Respect safe areas: the shell reports insets through the adapter; OpenTTD's toolbars/status bar are positioned inside them ([03-touch-interaction.md](03-touch-interaction.md) §7.4).
- Handle surface invalidation on background/foreground without crashing (validated by T-LIFE tests).

## 5. Input pipeline

```text
UIKit / SDL events
      │
      ▼
Input router (per-event source tagging)
      │  synthetic-mouse suppression: SDL_HINT_TOUCH_MOUSE_EVENTS=0,
      │  SDL_HINT_MOUSE_TOUCH_EVENTS=0  (verify names/behavior at P0.4)
      ├─────────────► physical pointer + keyboard ──► existing OpenTTD handlers (unchanged semantics)
      │
      └─► finger events ──► TouchInputTranslator
                                  │
                                  ├── pointer movement
                                  ├── primary click
                                  ├── secondary click
                                  ├── viewport pan
                                  ├── pinch zoom
                                  ├── drag construction
                                  └── precision mode
                                  ▼
                    Existing OpenTTD GUI and viewport handlers
```

Key properties:

- **Separation (EXP-7):** touch and physical-pointer events are distinguishable; direct gestures never produce duplicate synthetic-mouse actions.
- **Translation, not invasion:** gestures resolve to *existing* OpenTTD input concepts; iPad-specific behavior is not scattered through simulation or GUI code.
- **Tool-context awareness:** the translator queries the active tool state (none / line-construction / area / terraform / window-drag) to route one-finger drags ([03-touch-interaction.md](03-touch-interaction.md) §4).
- Generic improvements (expanded hit regions, touch settings plumbing) should be shaped for upstream submission.

Sketch of the core interface:

```cpp
class TouchInputTranslator {
public:
    void HandleFingerDown(const SDL_TouchFingerEvent &ev);
    void HandleFingerMotion(const SDL_TouchFingerEvent &ev);
    void HandleFingerUp(const SDL_TouchFingerEvent &ev);
    void SetToolContext(ToolContext ctx);     // called from GUI-side hook
    void Tick(uint32_t now_ms);               // drives long-press / precision timers
private:
    GestureStateMachine state;
    PrecisionMode precision;
};
```

## 6. Audio

SDL audio initially; a native `AVAudioSession` bridge only where SDL's lifecycle behavior is insufficient. Requirements: sound effects and music play; Bluetooth/AirPods and route changes never crash; system volume respected; interruptions (calls, Siri) pause and cleanly resume; no unintended background playback. Session category: `.ambient` is the default proposal (game audio mixes politely, silenced by system controls); revisit at P1.4 if music playback argues for `.playback` — record the decision as an ADR amendment.

## 7. Info.plist contract (initial)

| Key | Value | Why |
|-----|-------|-----|
| `UIApplicationSceneManifest` | one scene, `SceneDelegate` | scene lifecycle from day one |
| `UISupportedInterfaceOrientations~ipad` | landscape left + right only | landscape-only 1.0 |
| `UIRequiresFullScreen` | `true` for 1.0 | defers Stage Manager/split-view until Phase 4 |
| `UIApplicationSupportsIndirectInputEvents` | `true` | genuine mouse/trackpad events via SDL (PK-1) |
| `UIFileSharingEnabled` | `true` | saves visible in Files app |
| `LSSupportsOpeningDocumentsInPlace` | `true` | edit-in-place for the Documents tree |
| `CFBundleDocumentTypes` + `UTExportedTypeDeclarations` | `.sav`, `.scn` UTIs | open-with / Files integration (CO-14) |
| `NSLocalNetworkUsageDescription` | multiplayer LAN discovery text | Phase 5 |
| Status-bar / home-indicator keys | hide status bar; defer home indicator | immersive play; verify exact keys at P0.3 |

The builder records the final verified plist in the repo; this table is the contract, not the artifact.

## 8. Architecture decision records

| ID | Decision | Status | Rationale (summary) |
|----|----------|--------|---------------------|
| ADR-001 | Foundation = current upstream OpenTTD source; iOS fork, Android fork, and WASM wrappers rejected as foundations | Accepted | Upstream is modern C++/CMake, actively maintained, save-compatible; forks are stale (Android ≈ v13-era) or architecturally wrong (WASM: no sound, proxy multiplayer) |
| ADR-002 | Platform layer = SDL2 as shipped by upstream | Accepted | Upstream's SDL2 driver already covers rendering, audio, pointer, keyboard, text input; smallest patch surface |
| ADR-003 | Upstream vendored via squashed git subtree in `engine/` | Accepted | Single-repo CI simplicity; see [08-repository-strategy.md](08-repository-strategy.md) §2 for the full trade study vs. fork/submodule |
| ADR-004 | Renderer = SDL2 default/software path for 1.0; Metal only if profiling demands | Accepted | Minimize new code and risk; OpenTTD's workload is modest |
| ADR-005 | Landscape-only, single-scene, full-screen for 1.0 | Accepted | Cuts layout matrix; OpenTTD UI assumes wide aspect |
| ADR-006 | Touch handled by a dedicated platform-neutral translator; no gesture logic in simulation/GUI internals | Accepted | Upstreamability, testability, patch isolation |
| ADR-007 | Main-loop integration: Option A (SDL iOS main) unless P0.3 proves it non-viable, then Option B (host-driven `LoopOnce`) | Provisional — resolved at G0 | Least-invasive first |
| ADR-008 | Swift shell + single Obj-C++ bridge TU; no C++ interop experiments in shell code | Accepted | Boring, debuggable interop |

New ADRs append to this table (or to `docs/adr/` if they outgrow it) with status Proposed → Accepted/Rejected.
