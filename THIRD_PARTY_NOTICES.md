# OpenTTDPad third-party notices

This inventory covers the components linked or copied into the iPad Simulator
and device bundles. Release automation verifies it against the pinned build
inputs.

| Component | Version | Role | License | Corresponding source |
|---|---:|---|---|---|
| OpenTTD | 15.3 | Game engine | GNU GPL v2 | `engine/`, based on upstream commit `14ec60f248547d4d062a1160f0fc26d742319888` |
| SDL | 2.32.10 | iOS video, input, audio, and main shim | zlib license | `ref/SDL2` / [upstream tag](https://github.com/libsdl-org/SDL/releases/tag/release-2.32.10) |
| xz liblzma | 5.8.3 | Save compression | BSD Zero Clause (0BSD) | `ref/xz` / [upstream tag](https://github.com/tukaani-project/xz/releases/tag/v5.8.3) |
| libpng | 1.6.58 | PNG screenshots and heightmaps | PNG Reference Library License 2.0 | `ref/libpng` / [upstream tag](https://github.com/pnggroup/libpng/releases/tag/v1.6.58) |
| curl | 8.21.0 | HTTPS and online content | curl license | `ref/curl` / [upstream tag](https://github.com/curl/curl/releases/tag/curl-8_21_0) |
| Mbed TLS | 3.6.6 | TLS for curl | Apache-2.0 (selected from dual license) | `ref/mbedtls` / [official release](https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-3.6.6) |
| FreeType | 2.14.3 | Scalable international fonts | GNU GPL v2 (selected from dual license) | `ref/freetype` / [upstream tag](https://github.com/freetype/freetype/releases/tag/VER-2-14-3) |
| HarfBuzz | 14.2.0 | Complex-text shaping | Old MIT license | `ref/harfbuzz` / [upstream tag](https://github.com/harfbuzz/harfbuzz/releases/tag/14.2.0) |
| ICU | 78.1 | Unicode layout and bidirectional text | Unicode License v3 | `ref/icu` / [upstream tag](https://github.com/unicode-org/icu/releases/tag/release-78.1) |
| Mozilla CA certificate bundle | 2026-07-16 | HTTPS trust roots | Mozilla Public License 2.0 | `ref/game-files/cacert-2026-07-16.pem` / [curl CA extract](https://curl.se/docs/caextract.html) |
| zlib | iOS SDK 1.2.12 interface | Deflate compression | zlib license | [zlib source](https://zlib.net/) |
| OpenGFX | 8.0 | Free graphics base set | GNU GPL v2 | [official release](https://www.openttd.org/downloads/opengfx-releases/latest) and `ref/OpenGFX` |
| OpenSFX | 1.0.3 | Free sound base set | Collection CC BY-SA 3.0; component inventory includes GPLv2-or-later/CDDL 1.1 and permissive sources | [official release](https://www.openttd.org/downloads/opensfx-releases/latest) and `ref/OpenSFX` |
| OpenMSX | 0.4.2 | Free music base set | GNU GPL v2 | [official release](https://www.openttd.org/downloads/openmsx-releases/latest) and `ref/OpenMSX` |
| TimGM6mb | 1.3 | General MIDI soundfont | GNU GPL v2 | `ref/game-files/timgm6mb-soundfont_1.3/TimGM6mb.sf2` / [Debian source package](https://packages.debian.org/source/sid/timgm6mb-soundfont) |

The packaged `docs/licenses/` directory contains the exact license text shipped
with each pinned input. OpenTTDPad itself is not an official OpenTTD project or
release. No original Transport Tycoon Deluxe assets are bundled.
