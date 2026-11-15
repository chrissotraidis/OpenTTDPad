#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' "Usage: $0 <iPad Simulator UDID|booted>" >&2
    exit 64
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
device=$1
app="$repo_root/build/ios-sim/openttd.app"

xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
xcrun simctl launch --terminate-running-process "$device" com.chrissotraidis.openttdpad
