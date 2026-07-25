#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    printf '%s\n' "Usage: $0 <app bundle> <iphoneos|iphonesimulator> <build directory>" >&2
    exit 64
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app=$1
platform=$2
build_dir=$3
catalog="$build_dir/OpenTTDPadAssets.xcassets"
icon_set="$catalog/AppIcon.appiconset"
brand_color="$catalog/BrandTint.colorset"

rm -rf "$catalog"
mkdir -p "$icon_set" "$brand_color"
cp "$repo_root/os/ios/AppIconContents.json" "$icon_set/Contents.json"
cp "$repo_root/os/ios/BrandTintContents.json" "$brand_color/Contents.json"
cp "$repo_root/os/ios/AppIcon.png" "$icon_set/AppIcon.png"

xcrun actool \
    --compile "$app" \
    --platform "$platform" \
    --minimum-deployment-target 17.0 \
    --target-device ipad \
    --app-icon AppIcon \
    --output-partial-info-plist "$build_dir/OpenTTDPadAssetInfo.plist" \
    "$catalog"

/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$app/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons~ipad" "$app/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Merge $build_dir/OpenTTDPadAssetInfo.plist" "$app/Info.plist"
