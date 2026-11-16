#!/bin/sh
# Run OpenTTDPad's CI checks on this Mac.
#
#   scripts/check-local.sh            hygiene, host tests, Simulator UI tests, device build
#   scripts/check-local.sh --quick    hygiene and host tests only
#
# GitHub runs the same checks automatically once the repository is public.
# Simulator: OPENTTDPAD_SIMULATOR_UDID or OPENTTDPAD_SIMULATOR_DESTINATION
# (see scripts/test-simulator-ui.sh); the UI tests run silently.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"
quick=0
[ "${1:-}" = "--quick" ] && quick=1

step()
{
    printf '\n==> %s\n' "$1"
}

step "Shell scripts"
for script in scripts/*.sh; do sh -n "$script"; done

step "Whitespace (against origin/main)"
base=$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD)
git diff --check "$base" -- . ':(exclude)engine/**' ':(exclude)patches/**'

step "Release inventory"
./scripts/verify-release.sh

step "Host build and tests"
cmake -S engine -B build/macos -G Ninja -DCMAKE_BUILD_TYPE=Release -DOPTION_USE_ASSERTS=ON >/dev/null
cmake --build build/macos --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-8}"
ctest --test-dir build/macos --output-on-failure --exclude-regex '^regression_' --timeout 300

if [ "$quick" -eq 1 ]; then
    printf '\nQuick checks passed.\n'
    exit 0
fi

step "Simulator build and UI tests"
./scripts/build-simulator.sh
./scripts/test-simulator-ui.sh

step "Unsigned device build"
./scripts/build-device.sh
./scripts/verify-release.sh

printf '\nAll local checks passed.\n'
