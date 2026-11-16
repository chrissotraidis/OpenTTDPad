# Downstream engine patch log

Every edit to a file that existed in upstream OpenTTD 15.3 is listed here.
New files under dedicated iOS/touch directories are covered by their directory
purpose and normal review.

| Upstream file | Reason | Status | Upstream issue/PR |
|---|---|---|---|
| `engine/CMakeLists.txt` | Detect iOS, omit Cocoa packaging/frameworks, enable Objective-C++, build an app bundle, link SDL2main, curl/Mbed TLS, CoreText, and the SDK ICU ABI | downstream | not filed |
| `engine/cmake/FindICU.cmake` | Pair pinned ICU 78.1 headers with the unversioned Apple SDK `libicucore` ABI during iOS cross-compilation | downstream | not filed |
| `engine/src/CMakeLists.txt` | Include the isolated touch module | downstream | not filed |
| `engine/src/fontcache/freetypefontcache.cpp` | Ask the iOS CoreText bridge for a language-capable fallback font when a glyph is missing | downstream | not filed |
| `engine/src/music/CMakeLists.txt` | Exclude macOS-only Cocoa MIDI and register the native iOS Audio Unit MIDI driver | downstream | not filed |
| `engine/src/openttd.cpp` | Prevent iPad in-app Exit from ending the engine loop inside a still-live UIKit host; return active games to the title screen instead | downstream | not filed |
| `engine/src/sound/CMakeLists.txt` | Exclude macOS-only Cocoa audio on iOS | downstream | not filed |
| `engine/src/os/CMakeLists.txt` | Include the iOS platform directory | downstream | not filed |
| `engine/src/os/macosx/CMakeLists.txt` | Prevent macOS platform sources from entering iOS | downstream | not filed |
| `engine/src/os/unix/CMakeLists.txt` | Reuse portable Unix services on iOS | downstream | not filed |
| `engine/src/os/unix/unix.cpp` | Avoid including macOS services while retaining portable filesystem behavior | downstream | not filed |
| `engine/src/os/unix/unix_main.cpp` | Route startup through SDL's iOS main shim | downstream | not filed |
| `engine/src/stdafx.h` | Exclude CoreServices/ApplicationServices preamble on iOS | downstream | not filed |
| `engine/src/strings.cpp` | Use portable locale discovery on iOS | downstream | not filed |
| `engine/src/tests/CMakeLists.txt` | Register touch recognizer host tests | downstream | not filed |
| `engine/src/toolbar_gui.cpp` | Omit desktop-only Exit-program entries from the iPad save/load menus | downstream | not filed |
| `engine/src/intro_gui.cpp` | Omit the desktop Exit-program control from the iPad title screen | downstream | not filed |
| `engine/src/video/cocoa/CMakeLists.txt` | Exclude Cocoa renderer/window sources on iOS | downstream | not filed |
| `engine/src/video/sdl2_v.cpp` | Attach SDL to the active scene; force iPad fullscreen; separate finger/mouse sources; show the touch cursor without desktop hover tooltips; directly pan and zoom the viewport; probe and translate gestures; report the toolbar and status-bar edges so UIKit controls sit beside them | downstream | not filed |
| `engine/src/window.cpp`, `engine/src/window_gui.h` | Suppress desktop hover timing while the visible cursor is owned by direct touch; restore it for genuine mouse movement | downstream | not filed |
| `engine/src/network/core/http_curl.cpp` | Resolve the packaged Mozilla CA bundle before Unix host paths so iPad HTTPS retains peer verification | downstream | not filed |
| `engine/src/os/unix/crashlog_unix.cpp` | Record a stack trace in crash logs on iOS, which provides `execinfo` like glibc | downstream | not filed |

New downstream source surfaces:

- `engine/src/os/ios/` — scene/orientation, lifecycle, optional haptics, loupe,
  Files import/export, persistent touch settings, left/right safe-area-aware
  control placement, notices, and CoreText fallback services.
- `engine/src/music/ios_m.*` — native Audio Unit graph and bundled TimGM6mb MIDI playback.
- `engine/src/touch/` — platform-neutral touch thresholds, recognizer,
  finger-count transition reanchoring, and expanded-hit resolver.
- `engine/src/tests/gesture_state.cpp` — deterministic synthetic input streams.
- `os/ios/AppIconContents.json` and `BrandTintContents.json` — the generated
  asset catalog reuses the tracked GPLv2 upstream 1024 px artwork for the
  native iPad icon and adds one named tint; no duplicate binary artwork is
  added.

Pinned dependency patch:

- `patches/sdl2-uikit-root-controller.patch` — SDL 2.32.10 still clears and
  reassigns the same UIKit root view controller for an iOS 7 workaround. On the
  scene-based iPadOS 17 target this produces unbalanced appearance transitions.
  The patch keeps the existing controller and attaches its replacement SDL view
  directly; native presentation and finger routing are covered by XCTest.
  Bootstrap applies it idempotently and both iOS dependency builds consume it.
- `patches/sdl2-ios-scenes.patch` — the SDL 2.32.10 UIKit scene backport
  shared with the other Pad ports (chrissotraidis/SDL
  `pads/2.32.10-uikit-scenes`, including the window-ownership fix). SDL starts
  only after the application scene connects, creates its window on that scene,
  refits the window when the scene rotates, resizes or moves to another display,
  hands the window to a replacement scene, and reads orientation from the scene.
  Without it, an iPadOS 27 device showed a black screen while the game ran. The
  OpenTTDPad copy omits SDL's `configurationForConnectingSceneSession` so
  Info.plist keeps naming `OpenTTDPadSceneDelegate`, which subclasses
  `SDLUIKitSceneDelegate` and inherits its startup and geometry handling.

Prime directive check: no abandoned iOS fork code was copied. The platform
bridge and gesture state machine are original downstream implementations over
the recorded OpenTTD 15.3 base.
