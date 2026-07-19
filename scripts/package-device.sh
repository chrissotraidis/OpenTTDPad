#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir="$repo_root/build/ios-device"
app="$build_dir/openttd.app"

if [ ! -x "$app/openttd" ]; then
    printf '%s\n' "Build the device executable before packaging: $app/openttd" >&2
    exit 1
fi

rm -rf "$app/docs" "$app/soundfonts"
mkdir -p "$app/baseset" "$app/lang" "$app/ai" "$app/game" \
    "$app/scripts" "$app/soundfonts" "$app/docs/licenses"
rsync -a --delete "$build_dir/baseset/" "$app/baseset/"
rsync -a --delete "$build_dir/lang/" "$app/lang/"
rsync -a --delete "$build_dir/ai/" "$app/ai/"
rsync -a --delete "$build_dir/game/" "$app/game/"
rsync -a --delete "$repo_root/engine/bin/scripts/" "$app/scripts/"

rsync -a "$repo_root/ref/game-files/extracted/opengfx/opengfx-8.0/" "$app/baseset/"
rsync -a "$repo_root/ref/game-files/extracted/opensfx/opensfx-1.0.3/" "$app/baseset/"
rsync -a "$repo_root/ref/game-files/extracted/openmsx/openmsx-0.4.2/" "$app/baseset/"

cp "$repo_root/LICENSE" "$app/docs/COPYING-OpenTTD.md"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$app/docs/THIRD_PARTY_NOTICES.md"
cp "$repo_root/ref/SDL2/LICENSE.txt" "$app/docs/licenses/SDL-2.32.10.txt"
cp "$repo_root/ref/xz/COPYING.0BSD" "$app/docs/licenses/xz-liblzma-5.8.3.txt"
cp "$repo_root/ref/libpng/LICENSE" "$app/docs/licenses/libpng-1.6.58.txt"
cp "$repo_root/ref/curl/COPYING" "$app/docs/licenses/curl-8.21.0.txt"
cp "$repo_root/ref/mbedtls/LICENSE" "$app/docs/licenses/Mbed-TLS-3.6.6.txt"
cp "$repo_root/ref/freetype/docs/GPLv2.TXT" "$app/docs/licenses/FreeType-2.14.3-GPLv2.txt"
cp "$repo_root/ref/harfbuzz/COPYING" "$app/docs/licenses/HarfBuzz-14.2.0.txt"
cp "$repo_root/ref/icu/icu4c/LICENSE" "$app/docs/licenses/ICU-78.1.txt"
cp "$repo_root/ref/game-files/cacert-2026-07-16.pem" "$app/cacert.pem"
cp "$repo_root/ref/game-files/MPL-2.0.txt" "$app/docs/licenses/Mozilla-MPL-2.0.txt"
cp "$repo_root/ref/game-files/extracted/opengfx/opengfx-8.0/license.txt" \
    "$app/docs/licenses/OpenGFX-8.0.txt"
cp "$repo_root/ref/game-files/extracted/opensfx/opensfx-1.0.3/license.txt" \
    "$app/docs/licenses/OpenSFX-1.0.3.txt"
cp "$repo_root/ref/game-files/extracted/openmsx/openmsx-0.4.2/license.txt" \
    "$app/docs/licenses/OpenMSX-0.4.2.txt"
cp "$repo_root/ref/game-files/timgm6mb-soundfont_1.3/TimGM6mb.sf2" "$app/soundfonts/TimGM6mb.sf2"
cp "$repo_root/ref/game-files/timgm6mb-debian/debian/copyright" "$app/docs/licenses/TimGM6mb-1.3.txt"
"$repo_root/scripts/compile-app-assets.sh" "$app" iphoneos "$build_dir"

printf '%s\n' "Packaged unsigned device app at $app"
