#!/bin/sh
set -eu

# Usage: package-ipa.sh [copy.ipa]
# Writes build/artifacts/OpenTTDPad-unsigned.ipa and, when given, a copy at the
# requested path (PadMint passes its output path here).
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app="$repo_root/build/ios-device/openttd.app"
artifact_dir="$repo_root/build/artifacts"
payload_dir="$artifact_dir/Payload"
ipa="$artifact_dir/OpenTTDPad-unsigned.ipa"

if [ ! -x "$app/openttd" ]; then
    printf '%s\n' "Build the device app first: ./scripts/build-device.sh" >&2
    exit 1
fi

rm -rf "$payload_dir"
mkdir -p "$payload_dir"
cp -R "$app" "$payload_dir/"
find "$payload_dir" -exec touch -t 198001010000 {} +
rm -f "$ipa" "$ipa.sha256"
(
    cd "$artifact_dir"
    zip -Xqry "$(basename "$ipa")" Payload
)
(
    cd "$artifact_dir"
    shasum -a 256 "$(basename "$ipa")"
) > "$ipa.sha256"
rm -rf "$payload_dir"

printf '%s\n' "Packaged unsigned IPA: $ipa"
cat "$ipa.sha256"

if [ "$#" -gt 0 ]; then
    mkdir -p "$(dirname "$1")"
    cp "$ipa" "$1"
    printf '%s\n' "Copied the IPA to $1"
fi
