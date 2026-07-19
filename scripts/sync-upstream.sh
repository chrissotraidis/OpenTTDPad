#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tag=${1:-}

if [ -z "$tag" ]; then
    printf '%s\n' "Usage: $0 <verified-openttd-tag>" >&2
    exit 1
fi

if [ -n "$(git -C "$repo_root" status --porcelain)" ]; then
    printf '%s\n' "Refusing to update a dirty worktree." >&2
    exit 1
fi

git -C "$repo_root" subtree pull --prefix=engine \
    https://github.com/OpenTTD/OpenTTD.git "$tag" --squash

printf '%s\n' "Upstream merged. Rebuild every target and update docs/PATCHES.md before publishing."
