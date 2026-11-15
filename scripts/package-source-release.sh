#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
artifact_dir="$repo_root/build/artifacts"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/openttdpad-source.XXXXXX")
source_root="$work_dir/OpenTTDPad-source"
# A zip keeps the free-content archives inside within PadMint's three-level
# audit depth, and COPYFILE_DISABLE stops macOS adding ._ metadata files.
archive="$artifact_dir/OpenTTDPad-corresponding-source.zip"
export COPYFILE_DISABLE=1

if [ -n "$(git -C "$repo_root" status --porcelain)" ]; then
    printf '%s\n' "Refusing to package source from a dirty worktree; commit or stash changes first" >&2
    exit 1
fi

cleanup()
{
    rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$source_root" "$source_root/ref" "$artifact_dir"
git -C "$repo_root" archive HEAD | tar -x -C "$source_root"

for component in SDL2 xz libpng curl mbedtls freetype harfbuzz icu OpenGFX OpenSFX OpenMSX; do
    if [ ! -d "$repo_root/ref/$component" ]; then
        printf 'Missing corresponding source: ref/%s\n' "$component" >&2
        exit 1
    fi
    (
        cd "$repo_root/ref"
        # Left out because the release build never uses them: xz's
        # deliberately corrupt test archives, mbedtls's suite vectors and ICU's
        # Java implementation (only icu4c headers are used). Builds happen
        # under build/, never in ref/, so upstream folders such as FreeType's
        # builds/ and xz's build-aux/ are source and stay.
        tar --exclude='.git' \
            --exclude='xz/tests/files' --exclude='mbedtls/tests/suites/*.data' \
            --exclude='icu/icu4j' \
            -cf - "$component"
    ) | (
        cd "$source_root/ref"
        tar -xf -
    )
done

# The free content goes in unpacked, exactly as the app bundles it, so the
# release gates can read every file. SHA256SUMS records the original downloads.
mkdir -p "$source_root/ref/game-files"
(
    cd "$repo_root/ref/game-files"
    tar -cf - SHA256SUMS cacert-2026-07-16.pem MPL-2.0.txt \
        extracted/opengfx/opengfx-8.0 extracted/opensfx/opensfx-1.0.3 \
        extracted/openmsx/openmsx-0.4.2 timgm6mb-soundfont_1.3 timgm6mb-debian
) | (
    cd "$source_root/ref/game-files"
    tar -xf -
)

base_commit=$(sed -n 's/^- Subtree merge commit: `\([^`]*\)`.*/\1/p' \
    "$repo_root/UPSTREAM_VERSION.md")
if [ -z "$base_commit" ]; then
    printf '%s\n' "UPSTREAM_VERSION.md does not record the subtree merge commit" >&2
    exit 1
fi
git -C "$repo_root" format-patch --stdout "$base_commit..HEAD" > \
    "$artifact_dir/OpenTTDPad-downstream.patch"
rm -f "$archive"
(
    cd "$work_dir"
    zip -Xqr "$archive" OpenTTDPad-source
)
(
    cd "$artifact_dir"
    shasum -a 256 OpenTTDPad-corresponding-source.zip OpenTTDPad-downstream.patch
) > "$artifact_dir/OpenTTDPad-source.sha256"

printf 'Packaged corresponding source: %s\n' "$archive"
