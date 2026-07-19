# Implementation status

Updated: **2026-07-19**

## Environment

- Hardware: Apple Silicon (`arm64`), MacBook Air 10,1
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- iPhoneOS / Simulator SDK: 26.5 / 26.5
- Active Simulator: iPad Pro 13-inch (M5), iOS 26.5,
  `68016FEA-1887-4E05-A7F4-B26EC8572B8A`
- Apple Clang: 21.0.0; CMake: 4.4.0; Ninja: 1.13.2
- Physical iPad: not connected. Hardware-only acceptance remains open and is
  never represented as a Simulator pass.

## Roadmap

- [x] P0.0 — fact re-verification — `UPSTREAM_FACTS.md`
- [x] P0.1 — untouched macOS baseline — OpenTTD 15.3 Release, 96/96 tests,
  free content, deterministic save/reload
- [x] P0.2 build slices — host tools plus SDL 2.32.10, xz/liblzma 5.8.3,
  libpng 1.6.58, curl 8.21.0, Mbed TLS 3.6.6, SDK zlib, and OpenTTD link as
  arm64 Mach-O for Simulator; the unsigned arm64 device bundle is built by the
  same pinned dependency pipeline
- [x] P0.3 Simulator slice — scene-based native shell, landscape/fullscreen,
  free offline content, first playable game, manual save, force-terminate,
  relaunch, and load
- [~] P0.4 — raw input probe and explicit touch routing are working in
  Simulator; genuine physical pointer, Pencil, wheel, and hardware keyboard
  still require hardware
- [ ] Gate G0 — **not passed** until physical EXP-2/6/8 evidence exists
- [~] Phase 2 Simulator engineering — deliberately proceeding under the
  recorded execution-order deviation; this does not waive G0 or release gates
- [~] Phase 3 Simulator engineering — first-run touch coaching, online content
  over verified HTTPS, and bundled notices are working; Files import/export,
  settings UI, international text dependencies, and music playback remain

## Native build and packaging proof

The tracked engine subtree is based on upstream OpenTTD 15.3 commit
`14ec60f2486f43839dbdb05d1939a7a69c5a466e`. The iPad Simulator target links
all 839 original engine actions plus the downstream iOS/touch sources. The
packaged executable is arm64 and declares the iOS Simulator platform with a
17.0 minimum deployment target.

```sh
./scripts/bootstrap-reference.sh
./scripts/build-simulator.sh
./scripts/run-simulator.sh
file build/ios-sim/openttd.app/openttd
vtool -show-build build/ios-sim/openttd.app/openttd
```

The app bundle contains generated OpenTTD data/languages/scripts, GPL source
notice, OpenGFX 8.0, OpenSFX 1.0.3, OpenMSX 0.4.2, and complete dependency
notices. HTTPS uses static curl/Mbed TLS plus the dated Mozilla CA extract in
`cacert.pem`; the live Online Content catalog populated in Simulator. The
Simulator bundle is ad-hoc signed. No commercial TTD files are present.

## Simulator shell and persistence evidence

The first scene implementation rendered black because SDL 2's legacy window
was not attached to the active `UIWindowScene`. `OpenTTDPadSceneDelegate` now
records the active scene and the SDL window is attached after creation. A
second Simulator defect placed the game toolbar under the status bar; the iOS
window is now explicitly fullscreen/borderless and defers system gestures.

Persistence procedure executed on the iPad Pro Simulator:

1. Generate a playable game using direct screen taps.
2. Open Save Game from the top toolbar.
3. Focus the save-name field; confirm the iPad software keyboard appears and
   accepts text.
4. Save into `Documents/OpenTTD/save` and confirm the `.sav` exists in the
   resolved CoreSimulator app container.
5. Force-terminate the process and launch a new process.
6. Open Load Game, select the persisted file, and restore the same map.

Evidence:

- [first native Simulator frame](evidence/p0-ios-first-frame.png)
- [playable free-content game](evidence/p0-ios-playable-game.png)
- [scene-based landscape frame](evidence/p0-ios-scene-landscape.png)
- [save restored after process relaunch](evidence/p0-ios-reloaded-save.png)
- [HTTPS Online Content catalog](evidence/p3-ios-online-content.png)

The initial dependency spike omitted liblzma and could not reopen an LZMA save.
That failure was captured in the Simulator console and corrected by adding
pinned static xz/liblzma 5.8.3. Pinned static libpng 1.6.58 was added at the
same time for screenshots and heightmaps.

## Explicit touch router

`src/touch/gesture_state.*` is platform-neutral. `touch_settings.hpp` is the
single source of truth for the thresholds specified by doc 03. The recognizer
currently emits:

- direct tap and double-tap;
- delayed map pan only after the deliberate-drag threshold;
- desktop-primary drag for UI widgets and active construction tools;
- unconditional two-finger pan;
- two-finger secondary click;
- thresholded pinch zoom around the current centroid;
- long-press precision entry/move/commit events;
- momentum only after viewport pan;
- construction abort when a second finger lands;
- cancellation and button-state cleanup on focus loss.

Touch-only hit testing expands eligible undersized controls to at least 44 pt
without changing their drawn geometry. A 132 pt native loupe follows precision
mode, the first-run coach explains the gesture grammar, active construction has
a persistent 48+ pt Cancel control, and touch actions provide light haptics.

SDL's `TOUCH_MOUSE_EVENTS` and `MOUSE_TOUCH_EVENTS` hints are disabled on iOS.
Raw Simulator tapping produced `finger-down` and `finger-up` probe lines with
no synthetic mouse-button lines, while translated taps continued to operate
the UI. Real mouse/trackpad events remain on upstream's unchanged mouse path.

Host verification:

```text
ctest --test-dir build/macos-touch -R OpenTTDPad --output-on-failure
100% tests passed, 15/15

./scripts/test-simulator-ui.sh
3 XCTest UI scenarios: continuous drag + precision press; first-run coach;
background/foreground round-trip
```

XCTest's coordinate API supplies a true continuous drag in Simulator, while
the platform-neutral event-stream suite owns gesture boundary semantics.
Physical multitouch, Pencil, and real pointer feel remain hardware gates.

## Experiment ledger

| Experiment | State | Evidence / remaining gate |
|---|---|---|
| EXP-1 iOS arm64 compile | Build pass | arm64 Simulator and unsigned arm64 device bundles link; hardware install remains |
| EXP-2 visible iPad window | Partial | scene-based Simulator frame/playable map; physical iPad remains |
| EXP-3 software rendering | Partial | live Simulator gameplay; device performance/thermal remains |
| EXP-4 free content | Partial | all three audited free sets load offline in Simulator; physical remains |
| EXP-5 sandbox writes | Simulator pass | `.sav` confirmed in sandbox and loaded after force-terminate/relaunch |
| EXP-6 physical pointer | Open | genuine mouse/trackpad hardware required |
| EXP-7 touch separation | Simulator pass | raw finger-only probe after both SDL synthesis hints disabled |
| EXP-8 software keyboard | Partial | save-name field shown and typed in Simulator; device/hardware keyboard remains |
| EXP-9 lifecycle loop | Open | physical iPad required |
| EXP-10 touch construction | In progress | host recognizer and continuous-drag XCTest pass; full touch-only route and five-person trial remain |

## P0.1 baseline proof

```sh
cmake -S ref/OpenTTD -B ref/OpenTTD/build-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DOPTION_USE_ASSERTS=ON
cmake --build ref/OpenTTD/build-macos --parallel 8
ctest --test-dir ref/OpenTTD/build-macos --output-on-failure
```

Result: Release linked; upstream `ctest` passed **96/96** in 112.21 seconds.
The isolated build found OpenGFX 8.0, OpenSFX 1.0.3, and OpenMSX 0.4.2. See
[the generated map](evidence/p0-macos-new-game.png) and
[the reopened save](evidence/p0-macos-reloaded-save.png).

## Current next proof

Complete native Files import/export, settings, music, and international-text
support; then exercise the full touch-only road/rail/vehicle/orders route and
lifecycle matrix across three Simulator device classes. Physical-only gates
stay open until real hardware is connected.
