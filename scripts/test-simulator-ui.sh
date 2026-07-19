#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_build="$repo_root/build/ios-ui-tests"
destination=${OPENTTDPAD_SIMULATOR_DESTINATION:-"platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5"}

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
