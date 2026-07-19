# Downstream engine patch log

Every edit to a file that existed in upstream OpenTTD 15.3 is listed here.
New files under dedicated iOS/touch directories are covered by their directory
purpose and normal review.

| Upstream file | Reason | Status | Upstream issue/PR |
|---|---|---|---|
| `engine/CMakeLists.txt` | Detect iOS, omit Cocoa packaging/frameworks, enable Objective-C++, build an app bundle, link SDL2main and curl's static Mbed TLS chain | downstream | not filed |
| `engine/src/CMakeLists.txt` | Include the isolated touch module | downstream | not filed |
| `engine/src/music/CMakeLists.txt` | Exclude macOS-only Cocoa MIDI on iOS | downstream | not filed |
| `engine/src/sound/CMakeLists.txt` | Exclude macOS-only Cocoa audio on iOS | downstream | not filed |
| `engine/src/os/CMakeLists.txt` | Include the iOS platform directory | downstream | not filed |
| `engine/src/os/macosx/CMakeLists.txt` | Prevent macOS platform sources from entering iOS | downstream | not filed |
| `engine/src/os/unix/CMakeLists.txt` | Reuse portable Unix services on iOS | downstream | not filed |
| `engine/src/os/unix/unix.cpp` | Avoid including macOS services while retaining portable filesystem behavior | downstream | not filed |
| `engine/src/os/unix/unix_main.cpp` | Route startup through SDL's iOS main shim | downstream | not filed |
| `engine/src/stdafx.h` | Exclude CoreServices/ApplicationServices preamble on iOS | downstream | not filed |
| `engine/src/strings.cpp` | Use portable locale discovery on iOS | downstream | not filed |
| `engine/src/tests/CMakeLists.txt` | Register touch recognizer host tests | downstream | not filed |
| `engine/src/video/cocoa/CMakeLists.txt` | Exclude Cocoa renderer/window sources on iOS | downstream | not filed |
| `engine/src/video/sdl2_v.cpp` | Attach SDL to the active scene; force iPad fullscreen; separate finger/mouse sources; probe and translate direct gestures | downstream | not filed |
| `engine/src/network/core/http_curl.cpp` | Resolve the packaged Mozilla CA bundle before Unix host paths so iPad HTTPS retains peer verification | downstream | not filed |

New downstream source surfaces:

- `engine/src/os/ios/` — scene/orientation, lifecycle, haptics, loupe, and minimal native overlay services.
- `engine/src/touch/` — platform-neutral touch thresholds, recognizer, and expanded-hit resolver.
- `engine/src/tests/gesture_state.cpp` — deterministic synthetic input streams.

Prime directive check: no abandoned iOS fork code was copied. The platform
bridge and gesture state machine are original downstream implementations over
the recorded OpenTTD 15.3 base.
