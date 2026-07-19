#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ref_dir="$repo_root/ref"
game_dir="$ref_dir/game-files"
extract_dir="$game_dir/extracted"

clone_tag()
{
    destination=$1
    repository=$2
    tag=$3

    if [ -d "$destination/.git" ]; then
        return
    fi
    git clone --depth 1 --branch "$tag" "$repository" "$destination"
}

clone_commit()
{
    destination=$1
    repository=$2
    revision=$3

    if [ -d "$destination/.git" ]; then
        return
    fi
    git clone --filter=blob:none "$repository" "$destination"
    git -C "$destination" checkout --detach "$revision"
}

download()
{
    destination=$1
    url=$2

    if [ -f "$destination" ]; then
        return
    fi
    curl -fL --retry 3 --output "$destination" "$url"
}

mkdir -p "$ref_dir" "$game_dir" "$extract_dir"

clone_tag "$ref_dir/OpenTTD" https://github.com/OpenTTD/OpenTTD.git 15.3
clone_tag "$ref_dir/SDL2" https://github.com/libsdl-org/SDL.git release-2.32.10
clone_tag "$ref_dir/xz" https://github.com/tukaani-project/xz.git v5.8.3
clone_tag "$ref_dir/libpng" https://github.com/pnggroup/libpng.git v1.6.58
clone_tag "$ref_dir/curl" https://github.com/curl/curl.git curl-8_21_0
clone_commit "$ref_dir/OpenGFX" https://github.com/OpenTTD/OpenGFX.git \
    c51c904f4f6e7466ee73f907520ef7ea9a53bcbb
clone_commit "$ref_dir/OpenSFX" https://github.com/OpenTTD/OpenSFX.git \
    d0bf8d4deda22d5a7f8d01953433cb2644663e9f
clone_commit "$ref_dir/OpenMSX" https://github.com/OpenTTD/OpenMSX.git \
    312ca0ae46a271fb65ba49674b5e935ca0f41036

download "$game_dir/opengfx-8.0-all.zip" \
    https://cdn.openttd.org/opengfx-releases/8.0/opengfx-8.0-all.zip
download "$game_dir/opensfx-1.0.3-all.zip" \
    https://cdn.openttd.org/opensfx-releases/1.0.3/opensfx-1.0.3-all.zip
download "$game_dir/openmsx-0.4.2-all.zip" \
    https://cdn.openttd.org/openmsx-releases/0.4.2/openmsx-0.4.2-all.zip
download "$ref_dir/mbedtls-3.6.6.tar.bz2" \
    https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.6/mbedtls-3.6.6.tar.bz2
download "$game_dir/cacert-2026-07-16.pem" \
    https://curl.se/ca/cacert.pem
download "$game_dir/MPL-2.0.txt" \
    https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt

printf '%s  %s\n' \
    8fb65fae8dcae5840f793c0a334860a411f884cc537ea290ce1c52bb64ca007a \
    "$ref_dir/mbedtls-3.6.6.tar.bz2" | shasum -a 256 -c -
if [ ! -d "$ref_dir/mbedtls" ]; then
    mkdir -p "$ref_dir/mbedtls"
    tar -xjf "$ref_dir/mbedtls-3.6.6.tar.bz2" --strip-components=1 -C "$ref_dir/mbedtls"
fi

checksum_file="$game_dir/SHA256SUMS"
{
    echo "43a0c1dabf39cb865394f3a6cc36d4da5c10ecfaaf55652043104806810903be  $game_dir/opengfx-8.0-all.zip"
    echo "e0a218b7dd9438e701503b0f84c25a97c1c11b7c2f025323fb19d6db16ef3759  $game_dir/opensfx-1.0.3-all.zip"
    echo "5a4277a2e62d87f2952ea5020dc20fb2f6ffafdccf9913fbf35ad45ee30ec762  $game_dir/openmsx-0.4.2-all.zip"
} > "$checksum_file"
echo "3ff344e30b9b1ed2971044eabb438a08f2e2245ddb5f8ab1a3ad8b63ab4eaf91  $game_dir/cacert-2026-07-16.pem" >> "$checksum_file"
echo "fab3dd6bdab226f1c08630b1dd917e11fcb4ec5e1e020e2c16f83a0a13863e85  $game_dir/MPL-2.0.txt" >> "$checksum_file"
shasum -a 256 -c "$checksum_file"

mkdir -p "$extract_dir/opengfx" "$extract_dir/opensfx" "$extract_dir/openmsx"
unzip -qo "$game_dir/opengfx-8.0-all.zip" -d "$extract_dir/opengfx"
unzip -qo "$game_dir/opensfx-1.0.3-all.zip" -d "$extract_dir/opensfx"
unzip -qo "$game_dir/openmsx-0.4.2-all.zip" -d "$extract_dir/openmsx"

printf '%s\n' "Reference sources and audited free assets are ready under $ref_dir"
