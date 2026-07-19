# Local reference sources

`ref/` is the only location for downloaded source checkouts, release archives,
extracted game data, baseline builds, and temporary saves. The whole directory
is gitignored. Nothing under it is a release artifact or a substitute for the
eventual tracked `engine/` subtree.

## Layout

| Path | Purpose |
|---|---|
| `ref/OpenTTD/` | clean official 15.3 source and macOS baseline build |
| `ref/SDL2/` | pinned official SDL 2.32.10 source for iOS |
| `ref/xz/` | pinned official xz/liblzma 5.8.3 source for save compatibility |
| `ref/libpng/` | pinned official libpng 1.6.58 source for screenshots/heightmaps |
| `ref/curl/` | pinned official curl 8.21.0 source for HTTP/HTTPS content access |
| `ref/mbedtls/` | pinned official Mbed TLS 3.6.6 source used by static curl |
| `ref/freetype/` | pinned FreeType 2.14.3 source for scalable fonts |
| `ref/harfbuzz/` | pinned HarfBuzz 14.2.0 source for complex-text shaping |
| `ref/icu/` | pinned ICU 78.1 source/headers matching the iPadOS SDK library |
| `ref/OpenGFX/` | current official graphics source/credits reference |
| `ref/OpenSFX/` | current official sound source/license inventory reference |
| `ref/OpenMSX/` | current official music source/credits reference |
| `ref/game-files/` | checksummed official release archives, Mozilla CA bundle, TimGM6mb soundfont and Debian license metadata, extracted free game data, local configs, and saves |

## Rules

1. Download only from official upstream repositories or the official OpenTTD
   CDN; record URL, version, checksum, license, and date in
   `UPSTREAM_FACTS.md`.
2. Original TTD files are prohibited even under `ref/`; this directory is not
   permission to download or redistribute commercial content.
3. Do not add `ref/` with a force flag. Hygiene CI must fail if any path under
   `ref/`, original TTD filename, or known prohibited content hash is tracked.
4. Packaging copies only audited, version-pinned inputs from `ref/` through a
   reproducible script. Manual copies are acceptable only for Phase 0 probes.
5. A release bundles all required notices and corresponding source; ignored
   reference files alone never satisfy GPL or Creative Commons obligations.
