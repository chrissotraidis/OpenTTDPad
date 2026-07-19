#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
failed=0

fail()
{
    printf 'FAIL: %s\n' "$1" >&2
    failed=1
}

if git -C "$repo_root" ls-files 'ref/**' | grep -q .; then
    fail "gitignored ref/ content is tracked"
fi

tracked_names=$(git -C "$repo_root" ls-files)
if printf '%s\n' "$tracked_names" | grep -Eiq '(^|/)(trg[achr0-9]*\.grf|sample\.cat)$'; then
    fail "a prohibited original Transport Tycoon Deluxe asset name is tracked"
fi

for required in \
    LICENSE THIRD_PARTY_NOTICES.md \
    docs/IMPLEMENTATION_GOAL.md docs/PATCHES.md docs/STATUS.md \
    scripts/bootstrap-ios.sh scripts/build-simulator.sh scripts/build-device.sh \
    scripts/compile-app-assets.sh scripts/package-ipa.sh \
    scripts/package-source-release.sh patches/sdl2-uikit-root-controller.patch \
    os/ios/AppIconContents.json os/ios/BrandTintContents.json; do
    if [ ! -f "$repo_root/$required" ]; then
        fail "missing required release input: $required"
    fi
done

for component in OpenTTD SDL xz libpng curl 'Mbed TLS' FreeType HarfBuzz ICU \
    'Mozilla CA' OpenGFX OpenSFX OpenMSX TimGM6mb; do
    if ! grep -Fq "$component" "$repo_root/THIRD_PARTY_NOTICES.md"; then
        fail "third-party inventory omits $component"
    fi
done

verify_app()
{
    app=$1
    platform=$2
    if [ ! -x "$app/openttd" ]; then
        return
    fi
    for resource in Assets.car baseset lang scripts soundfonts/TimGM6mb.sf2 \
        cacert.pem docs/THIRD_PARTY_NOTICES.md; do
        if [ ! -e "$app/$resource" ]; then
            fail "$platform app omits $resource"
        fi
    done
    if ! file "$app/openttd" | grep -q 'arm64'; then
        fail "$platform executable is not arm64"
    fi
}

verify_app "$repo_root/build/ios-sim/openttd.app" Simulator
verify_app "$repo_root/build/ios-device/openttd.app" device

if [ "$failed" -ne 0 ]; then
    exit 1
fi

printf '%s\n' "Release hygiene passed: tracked assets, notices, scripts, and available app bundles."
