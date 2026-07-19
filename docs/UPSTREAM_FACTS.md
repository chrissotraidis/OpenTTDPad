# Upstream facts

Load-bearing facts re-verified for P0.0 on **2026-07-18**. When a source fact
changes, update this file before changing architecture or build inputs.

| Fact | Verified value | Primary source and local proof | Result |
|---|---|---|---|
| Current stable OpenTTD | 15.3, released 2026-04-04, commit `14ec60f248547d4d062a1160f0fc26d742319888` | [official releases](https://github.com/OpenTTD/OpenTTD/releases/tag/15.3); `git -C ref/OpenTTD describe --tags --exact-match` | Matches PRD |
| Current testing OpenTTD | 16.0-beta2, released 2026-07-12 | [official releases](https://github.com/OpenTTD/OpenTTD/releases/tag/16.0-beta2) | Matches PRD; stable remains the base |
| Minimum CMake | 3.17 | [15.3 CMakeLists.txt](https://github.com/OpenTTD/OpenTTD/blob/15.3/CMakeLists.txt#L1); local line 1 | **PRD said 3.16; verified upstream wins** |
| C++ language level | C++20, required | [15.3 CMakeLists.txt](https://github.com/OpenTTD/OpenTTD/blob/15.3/CMakeLists.txt#L45-L46) | Matches PRD |
| Upstream SDL generation | SDL2 APIs and SDL2 video drivers | [15.3 video sources](https://github.com/OpenTTD/OpenTTD/tree/15.3/src/video); `sdl2_v.cpp`, `sdl2_default_v.cpp`, `sdl2_opengl_v.cpp` | Matches PRD |
| Upstream finger handling | No `SDL_FINGERDOWN`, `SDL_FINGERUP`, or `SDL_FINGERMOTION` handling in 15.3 engine/platform sources | Local `rg` over `src/`, `os/`, and `cmake/` returned no match | Confirms touch gap |
| Host-tool cross build | `OPTION_TOOLS_ONLY=ON`, target `tools`, then `HOST_BINARY_DIR=<native build>` | [official emscripten instructions](https://github.com/OpenTTD/OpenTTD/blob/15.3/os/emscripten/README.md); local `cmake/Options.cmake` | Exact PRD placeholders confirmed |
| SDL2 pin | Stable SDL 2.32.10, tag commit `5d249570393f7a37e037abf22cd6012a4cc56a71` | [official SDL tag](https://github.com/libsdl-org/SDL/releases/tag/release-2.32.10); pinned checkout `ref/SDL2` | Use source build; Homebrew `sdl2` now resolves to `sdl2-compat` |
| Touch/mouse synthesis hints | `SDL_HINT_TOUCH_MOUSE_EVENTS` and `SDL_HINT_MOUSE_TOUCH_EVENTS` exist; value `0` disables the corresponding synthesis path | [SDL2 hint docs](https://wiki.libsdl.org/SDL2/SDL_HINT_TOUCH_MOUSE_EVENTS), [mouse-to-touch docs](https://wiki.libsdl.org/SDL2/SDL_HINT_MOUSE_TOUCH_EVENTS); pinned headers/source | Matches PRD |
| iOS indirect pointer input | SDL2 UIKit reads `UIApplicationSupportsIndirectInputEvents` and warns when absent; official iOS demos set it to `YES` | Pinned SDL2 `src/video/uikit/SDL_uikitevents.m` and `Xcode-iOS/Demos` | Matches PRD |
| UIKit scene lifecycle | Apps built with the iOS/iPadOS 27 SDK must adopt scenes or fail to launch | [Apple migration guidance](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle) | Matches PRD; implement from first frame |
| Local/current Apple toolchain | Xcode 26.6 build 17F113; iPhoneOS and Simulator SDK 26.5; iOS 18.5 and 26.5 Simulator runtimes installed. Xcode 27 beta 3 is newer but not the stable build base. | `xcodebuild -version`, `xcrun --sdk ... --show-sdk-version`, `simctl list`; [Apple Xcode support](https://developer.apple.com/support/xcode/) | Stable installed toolchain is sufficient |
| Minimum iPadOS | 17.0 | Project decision from PRD proposal; supported by current Xcode/SDK and leaves broad arm64 coverage | Accepted for initial target |

## Free base-content audit

All release archives below were downloaded from the official OpenTTD CDN into
`ref/game-files/`, verified by SHA-256, and extracted only under `ref/`.

| Set | Release | SHA-256 | License and bundling requirements |
|---|---:|---|---|
| OpenGFX | 8.0 | `43a0c1dabf39cb865394f3a6cc36d4da5c10ecfaaf55652043104806810903be` | GPLv2. Bundle unmodified binary data with GPLv2 text, copyright/credits, source offer/access, and clear attribution. [Official download](https://www.openttd.org/downloads/opengfx-releases/latest) |
| OpenSFX | 1.0.3 | `e0a218b7dd9438e701503b0f84c25a97c1c11b7c2f025323fb19d6db16ef3759` | Collection is CC BY-SA 3.0; original component sounds are dual-licensed GPLv2-or-later or CDDL 1.1 and individual sources may be more permissive. Bundle the unmodified set with its complete `license.txt`, `readme.txt`, attribution/credits, and source-license inventory. [Official download](https://www.openttd.org/downloads/opensfx-releases/latest) |
| OpenMSX | 0.4.2 | `5a4277a2e62d87f2952ea5020dc20fb2f6ffafdccf9913fbf35ad45ee30ec762` | GPLv2. Bundle with GPLv2 text, author credits, corresponding source access, and attribution. [Official download](https://www.openttd.org/downloads/openmsx-releases/latest) |

OpenGFX and OpenSFX are mandatory offline content for 1.0. OpenMSX remains
optional if final bundle size, MIDI playback, or product review favors an
on-demand download; any such choice must be recorded before P1.5 closes.

## Verified local reference revisions

| Checkout | Revision |
|---|---|
| `ref/OpenTTD` | `14ec60f248547d4d062a1160f0fc26d742319888` (tag 15.3) |
| `ref/SDL2` | `5d249570393f7a37e037abf22cd6012a4cc56a71` (tag release-2.32.10) |
| `ref/OpenGFX` | `c51c904f4f6e7466ee73f907520ef7ea9a53bcbb` |
| `ref/OpenSFX` | `d0bf8d4deda22d5a7f8d01953433cb2644663e9f` |
| `ref/OpenMSX` | `312ca0ae46a271fb65ba49674b5e935ca0f41036` |
