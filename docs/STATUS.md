# Implementation status

Updated: **2026-07-24**

## Environment

- Hardware: Apple Silicon (`arm64`), MacBook Air 10,1
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- iPhoneOS / Simulator SDK: 26.5 / 26.5
- Simulator matrix: iPad Pro 13-inch (M5), iPad (A16), and iPad mini (A17 Pro),
  all on iOS 26.5
- Apple Clang: 21.0.0; CMake: 4.4.0; Ninja: 1.13.2
- Physical iPad: not connected. Hardware-only acceptance remains open and is
  never represented as a Simulator pass.

## Roadmap

- [x] P0.0 — fact re-verification — `UPSTREAM_FACTS.md`
- [x] P0.1 — untouched macOS baseline — OpenTTD 15.3 Release, 96/96 tests,
  free content, deterministic save/reload
- [x] P0.2 build slices — host tools plus SDL 2.32.10, xz/liblzma 5.8.3,
  libpng 1.6.58, curl 8.21.0, Mbed TLS 3.6.6, FreeType 2.14.3, HarfBuzz
  14.2.0, ICU 78.1 headers/SDK library, SDK zlib, and OpenTTD link as arm64
  Mach-O for Simulator; the unsigned arm64 device bundle uses the same pins
- [x] P0.3 Simulator slice — scene-based native shell, landscape/fullscreen,
  free offline content, first playable game, manual save, force-terminate,
  relaunch, and load
- [~] P0.4 — raw input probe and explicit touch routing are working in
  Simulator; genuine physical pointer, Pencil, wheel, and hardware keyboard
  still require hardware
- [ ] Gate G0 — **not passed** until physical EXP-2/6/8 evidence exists
- [~] Phase 2 Simulator engineering — deliberately proceeding under the
  recorded execution-order deviation; this does not waive G0 or release gates
- [x] Phase 3 Simulator engineering — first-run touch coaching, Files
  import/export, persistent touch settings, bundled notices, verified HTTPS
  content, complex international text, and native General MIDI playback work
  in the packaged app
- [x] Release engineering — clean-clone bootstrap, Simulator and unsigned
  device builds, checksummed unsigned IPA, source-release packager, dependency
  inventory, forbidden-asset scan, and six GitHub Actions workflows are tracked

The workflow YAML and scripts pass local syntax/hygiene validation. The current
local tree has not been pushed, so GitHub Actions has not exercised this exact
revision; local build and Simulator evidence, not an unrun CI declaration, is
the proof recorded here.

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
notice, OpenGFX 8.0, OpenSFX 1.0.3, OpenMSX 0.4.2, TimGM6mb 1.3, and complete
dependency notices. HTTPS uses static curl/Mbed TLS plus the dated Mozilla CA
extract in `cacert.pem`; the live Online Content catalog populated in
Simulator. FreeType 2.14.3 and HarfBuzz 14.2.0 are static; pinned ICU 78.1
headers pair with the SDK `libicucore`, and CoreText supplies system fallback
fonts. The Simulator bundle is ad-hoc signed. The device executable is arm64,
targets iOS 17.0, links only Apple system dylibs/frameworks, and packages as an
unsigned IPA. Both build paths compile a native asset catalog from the tracked,
downstream OpenTTDPad app icon. The 1024 × 1024 source is opaque, and the
current Simulator `Assets.car` contains the matching AppIcon rendition. No
commercial TTD files are present.

Final unsigned IPA:

```text
build/artifacts/OpenTTDPad-unsigned.ipa
SHA-256 365e049461eb4108e2224860fa84f4a8568054cbfd7f5d4f8787f39dff336e26
```

Two consecutive packaging runs produced that same checksum. The IPA packager
normalizes payload timestamps and strips ZIP metadata so the unsigned artifact
is reproducible from an unchanged device app.

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
- [Arabic right-to-left UI rendered with system fallback](evidence/p3-ios-arabic-rtl.png)
- [fresh 2026-07-24 Simulator launch](evidence/2026-07-24-simulator-launch.png)

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
- seamless reanchoring when a two-finger pan or pinch drops to one finger;
- construction abort when a second finger lands;
- cancellation and button-state cleanup on focus loss.

Touch-only hit testing expands eligible undersized controls to at least 44 pt
without changing their drawn geometry. A 132 pt native loupe follows precision
mode, the first-run coach explains the gesture grammar, active construction has
a persistent 44+ pt Cancel control, and touch actions provide light haptics.
The native settings sheet can put the options and construction controls on the
left or right for thumb reach and can disable haptic feedback. Tool hints stay
clamped inside the safe area on either side. The UIKit overlays compensate for
SDL's high-DPI coordinate space, and XCTest asserts the coach, options, and
active-tool controls remain at least 44 pt on screen. Both settings sheets
provide an explicit visible Done action on iPad.

SDL's `TOUCH_MOUSE_EVENTS` and `MOUSE_TOUCH_EVENTS` hints are disabled on iOS.
Raw Simulator tapping produced `finger-down` and `finger-up` probe lines with
no synthetic mouse-button lines, while translated taps continued to operate
the UI. Real mouse/trackpad events remain on upstream's unchanged mouse path.

Host verification:

```text
ctest --test-dir build/macos --output-on-failure --exclude-regex '^regression_' --timeout 300
100% tests passed, 111/111 (2026-07-24)

ctest --test-dir build/macos-touch -R OpenTTDPad --output-on-failure
100% tests passed, 17/17

ctest --test-dir build/macos-touch --output-on-failure
100% tests passed, 113/113

./scripts/test-simulator-ui.sh
7 XCTest UI scenarios: 44 pt native controls; continuous map drag + precision press; touch-only Rail
and Road palettes, construction selection, continuous construction drags, and
cancellation; live left/right active-tool placement; first-run coach;
background/foreground round-trip; native touch settings and licenses; ZIP save
export/share sheet
```

All seven scenarios passed again on every tested size class on 2026-07-24
(**21/21 fresh invocations**):

| Simulator | Result bundle |
|---|---|
| iPad Pro 13-inch (M5) | `build/xcode-derived-data-ui/Logs/Test/Test-OpenTTDPadUITests-2026.07.24_22-58-19--0500.xcresult` |
| iPad (A16) | `build/xcode-derived-data-ui/Logs/Test/Test-OpenTTDPadUITests-2026.07.24_23-01-44--0500.xcresult` |
| iPad mini (A17 Pro) | `build/xcode-derived-data-ui/Logs/Test/Test-OpenTTDPadUITests-2026.07.24_23-05-44--0500.xcresult` |

The UI runner resolves and boots the requested Simulator, waits for it to be
ready, and installs `build/ios-sim/openttd.app` before XCTest. This closes a
stale-install hole in the earlier harness: every result above exercised the
exact current binary rather than whatever happened to be installed already.
The packaged OpenTTDPad app has a native asset catalog, launch-screen metadata,
and balanced UIKit presentation transitions.

XCTest's coordinate API supplies a true continuous drag in Simulator, while
the platform-neutral event-stream suite owns gesture boundary semantics. The
construction scenario also caught a real integration defect: global bezel
edge rejection made safe-area-adjacent toolbar widgets untappable. Rejection is
now limited to viewport gestures, and the test asserts that a finger opens the
exact Rail palette before operating Autorail. Expanding the same proof to Road
caught a second size-class defect: the wide Pro toolbar and its one-row Road
menu need different normalized targets than compact iPads. The suite now
asserts the exact transport palette on every size before construction. Physical
multitouch, Pencil, and real pointer feel remain hardware gates.

This iteration also caught two native-control defects. SDL's high-DPI window
coordinates made visually declared 52 pt controls measure only 26 pt to
XCTest; overlay geometry now scales to real screen points and is guarded by
minimum-target assertions. iPad action-sheet popovers omit cancel-style actions,
so Touch Controls and Layout & Feedback now expose a normal Done action instead
of relying on outside-tap dismissal.

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
| EXP-9 lifecycle loop | Partial | one background/foreground recovery cycle passes on all three Simulators; ten-cycle physical run remains |
| EXP-10 touch construction | Simulator integration pass; usability gate open | finger-only Rail and Road palettes → direct tools → continuous placement drags → native Cancel pass across three size classes; full T-GAME route and five-person first-use trial remain |

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

Exercise the complete touch-only road/rail/vehicle/orders T-GAME route with
first-time users, then run physical-device pointer/Pencil/multitouch, audio
route, performance/thermal, ten-cycle lifecycle, and desktop save round-trip
gates when an iPad is connected. Simulator-verifiable implementation and
automation are complete; hardware-only gates stay explicitly open.
