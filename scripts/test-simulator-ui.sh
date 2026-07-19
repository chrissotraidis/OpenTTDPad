#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_build="$repo_root/build/ios-ui-tests"
destination=${OPENTTDPAD_SIMULATOR_DESTINATION:-"platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5"}
app="$repo_root/build/ios-sim/openttd.app"

if [ ! -x "$app/openttd" ]; then
    printf '%s\n' "Build the Simulator app first: ./scripts/build-simulator.sh" >&2
    exit 1
fi

device_id=${OPENTTDPAD_SIMULATOR_UDID:-}
if [ -z "$device_id" ]; then
    device_id=$(printf '%s\n' "$destination" | sed -n 's/.*id=\([^,]*\).*/\1/p')
fi
if [ -z "$device_id" ]; then
    device_name=$(printf '%s\n' "$destination" | sed -n 's/.*name=\([^,]*\).*/\1/p')
    device_os=$(printf '%s\n' "$destination" | sed -n 's/.*OS=\([^,]*\).*/\1/p')
    device_line=$(xcrun simctl list devices available | awk -v runtime="-- iOS $device_os --" -v name="$device_name" '
        $0 == runtime { active = 1; next }
        /^-- / { active = 0 }
        active && index($0, "    " name " (") == 1 { print; exit }
    ')
    device_id=$(printf '%s\n' "$device_line" | sed -E -n 's/.*\(([0-9A-F-]{36})\).*/\1/p')
fi
if [ -z "$device_id" ]; then
    printf '%s\n' "Could not resolve an available Simulator from: $destination" >&2
    exit 1
fi

if ! xcrun simctl boot "$device_id" 2>/dev/null; then
    : # Already booted is expected during repeated local runs.
fi
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app"
destination="platform=iOS Simulator,id=$device_id"

cmake -S "$repo_root/tests/ios-ui" -B "$test_build" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0

cmake \
    -DOPENTTDPAD_UI_TEST_PROJECT="$test_build/OpenTTDPadUITests.xcodeproj" \
    -DOPENTTDPAD_UI_TEST_SCHEME="$test_build/OpenTTDPadUITests.xcodeproj/xcshareddata/xcschemes/OpenTTDPadUITests.xcscheme" \
    -P "$repo_root/tests/ios-ui/configure-scheme.cmake"

xcodebuild test \
    -project "$test_build/OpenTTDPadUITests.xcodeproj" \
    -scheme OpenTTDPadUITests \
    -destination "$destination" \
    -derivedDataPath "$repo_root/build/xcode-derived-data-ui" \
    CODE_SIGNING_ALLOWED=NO
