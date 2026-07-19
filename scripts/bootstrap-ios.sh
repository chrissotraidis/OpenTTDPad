#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

require_tool()
{
    if ! command -v "$1" >/dev/null 2>&1; then
        printf '%s\n' "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcodebuild
require_tool xcrun
require_tool cmake
require_tool ninja
require_tool git
require_tool curl
require_tool shasum
require_tool unzip

if ! xcodebuild -version >/dev/null 2>&1; then
    printf '%s\n' "Xcode is not selected. Run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

printf '%s\n' "Preparing pinned sources and freely redistributable game content..."
"$repo_root/scripts/bootstrap-reference.sh"

printf '%s\n' "Building the arm64 iPad Simulator app..."
"$repo_root/scripts/build-simulator.sh"

printf '%s\n' ""
printf '%s\n' "OpenTTDPad is ready at $repo_root/build/ios-sim/openttd.app"
printf '%s\n' "Run it with: ./scripts/run-simulator.sh"
printf '%s\n' "Build the unsigned device app with: ./scripts/build-device.sh"
printf '%s\n' "Package an unsigned IPA with: ./scripts/package-ipa.sh"
printf '%s\n' "Device installation requires your own Apple signing identity and profile."
