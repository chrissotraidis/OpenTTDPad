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
| xz/liblzma pin | 5.8.3, commit `4b73f2ec19a99ef465282fbce633e8deb33691b3` | [official xz repository](https://github.com/tukaani-project/xz/releases/tag/v5.8.3); `ref/xz` | Required static save codec; only liblzma is built |
| libpng pin | 1.6.58, commit `3061454d980de7d53608f594194cfac722721d2a` | [official libpng repository](https://github.com/pnggroup/libpng/releases/tag/v1.6.58); `ref/libpng` | Required static screenshot/heightmap codec |
| curl pin | 8.21.0, commit `68720b4837284335b2d63cb358f8f6ce65f5bc55` | [official curl release table](https://curl.se/docs/releases.html); `ref/curl` | Static HTTP/HTTPS, IPFS/IPNS, and WebSocket client; unused protocols disabled |
| Mbed TLS pin | 3.6.6 LTS, archive SHA-256 `8fb65fae8dcae5840f793c0a334860a411f884cc537ea290ce1c52bb64ca007a` | [official security release](https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-3.6.6); verified archive under `ref/` | Static TLS backend for curl |
| HTTPS trust roots | Mozilla CA extract dated 2026-07-16, 119 certificates, SHA-256 `3ff344e30b9b1ed2971044eabb438a08f2e2245ddb5f8ab1a3ad8b63ab4eaf91` | [curl CA extract service](https://curl.se/docs/caextract.html); bundled `cacert.pem` | MPL 2.0 bundle with peer verification retained |
| FreeType pin | 2.14.3, commit `0a0221a1347e2f1e07c395263540026e9a0aa7c7` | [official tag](https://github.com/freetype/freetype/releases/tag/VER-2-14-3); `ref/freetype` | Static scalable-font rasterizer; GPLv2 license selected for this GPLv2 application |
| HarfBuzz pin | 14.2.0, commit `b0ffab42d473eb380ad0fcf42730e0f1868cbc97` | [official tag](https://github.com/harfbuzz/harfbuzz/releases/tag/14.2.0); `ref/harfbuzz` | Static complex-text shaper using FreeType |
| ICU pin | 78.1, commit `049e0d6a420629ac7db77256987d083a563287b5` | [official tag](https://github.com/unicode-org/icu/releases/tag/release-78.1); `ref/icu` | Pinned headers match the SDK's `libicucore`; enables bidi/layout without a bundled dylib |
| General MIDI soundfont | TimGM6mb 1.3, upstream archive SHA-256 `af8f3a00e416dfb262bcaa904a1c84df04a51b72bbc1313aed012bc754bdf99b` | [Debian source package](https://packages.debian.org/source/sid/timgm6mb-soundfont); Debian metadata archive SHA-256 `993893c5b6265a3f7972a38d055d450d08873d097a2a2c41b010bd1858cc068c` | GPLv2 soundfont drives the native Audio Unit MIDI synthesizer |

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
| `ref/xz` | `4b73f2ec19a99ef465282fbce633e8deb33691b3` (tag v5.8.3) |
| `ref/libpng` | `3061454d980de7d53608f594194cfac722721d2a` (tag v1.6.58) |
| `ref/curl` | `68720b4837284335b2d63cb358f8f6ce65f5bc55` (tag curl-8_21_0) |
| `ref/mbedtls` | 3.6.6 release archive, SHA-256 recorded above |
| `ref/freetype` | `0a0221a1347e2f1e07c395263540026e9a0aa7c7` (tag VER-2-14-3) |
| `ref/harfbuzz` | `b0ffab42d473eb380ad0fcf42730e0f1868cbc97` (tag 14.2.0) |
| `ref/icu` | `049e0d6a420629ac7db77256987d083a563287b5` (tag release-78.1) |
| `ref/OpenGFX` | `c51c904f4f6e7466ee73f907520ef7ea9a53bcbb` |
| `ref/OpenSFX` | `d0bf8d4deda22d5a7f8d01953433cb2644663e9f` |
| `ref/OpenMSX` | `312ca0ae46a271fb65ba49674b5e935ca0f41036` |
