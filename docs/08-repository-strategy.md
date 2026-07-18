# 08 — Repository Strategy

How upstream OpenTTD is vendored, where iPad code lives, the patch-isolation policy, and the upstream-sync process. Goal: an **upstream-first downstream fork** whose iPad delta stays small, documented, and partially upstreamable (PG-9, NFR-MNT-1/2).

---

## 1. Principles

- **BR-20.** Track official OpenTTD releases; the base tag/commit is always recorded and mechanically checkable.
- **BR-21.** iPad-specific platform files are isolated in dedicated directories; simulation logic is never modified (prime directive 3).
- **BR-22.** Generic improvements (touch translation, hit-region expansion, scaling separation) are shaped for upstream submission.
- **BR-23.** GPL history and notices are preserved; a pure wrapper repo is insufficient because input behavior and UI hit testing require engine changes — so those changes are managed as a disciplined patch series instead.

## 2. Vendoring decision (ADR-003)

Options considered:

| Option | Pros | Cons |
|---|---|---|
| GitHub fork of OpenTTD with an `ipad` branch | cleanest upstream diffing; PRs upstream trivial | product code (shell, scripts, docs) awkward inside the engine repo; rebase-heavy |
| Submodule pointing at a patched fork | small product repo | submodule friction in CI and for contributors; two repos to keep honest |
| **Squashed git subtree in `engine/` (chosen)** | one repo, one clone, CI-simple; full tree at a pinned version; patches visible in-repo | upstream history squashed (mitigated by `UPSTREAM_VERSION.md` + format-patch series); subtree pulls need care |

`git subtree add --squash --prefix=engine <openttd-remote> <release-tag>` establishes the base; `UPSTREAM_VERSION.md` records remote URL, tag, and commit hash. Full upstream history remains available from the upstream remote; squashing does not remove any GPL notice from the tree itself.

## 3. Directory layout

```text
OpenTTDPad/
├── docs/                     # this PRD suite + STATUS.md, PATCHES.md, UPSTREAM_FACTS.md, DEVIATIONS.md, reports/
├── engine/                   # upstream OpenTTD subtree (pinned; see UPSTREAM_VERSION.md)
│   └── src/
│       ├── os/ios/           # NEW: platform adapter (ios_paths, ios_lifecycle, …)
│       ├── touch/            # NEW: TouchInputTranslator, gesture_state, precision_mode, touch_settings
│       └── video/            # ios driver sibling to sdl2_v.* (minimal edits elsewhere)
├── os/ios/                   # native shell: AppDelegate.swift, SceneDelegate.swift, OpenTTDBridge.mm,
│                             # DocumentManager.swift, AudioSessionManager.swift, Onboarding*, Info.plist
├── cmake/
│   └── ios.toolchain.cmake
├── scripts/                  # bootstrap-ios.sh, build-*.sh, package-ipa.sh, sync-upstream.sh, deps/
├── assets/
│   └── licenses/             # base-set + third-party license texts packaged into the app
├── tests/
│   ├── touch/                # gesture state-machine unit tests (host-runnable)
│   ├── file_import/          # path + import/export tests
│   └── lifecycle/            # scripted lifecycle harness notes + XCUITest where feasible
├── .github/workflows/        # CI per doc 07 §5
├── README.md · LICENSE · THIRD_PARTY_NOTICES.md · UPSTREAM_VERSION.md
```

Adjust exact in-engine placement to **upstream conventions** (e.g. if upstream expects new video drivers registered in a particular table, follow it) rather than forcing this layout verbatim — but the separation rule (new code in new dirs; minimal edits elsewhere) is binding.

## 4. Patch policy

- **BR-24.** Every modification to a pre-existing upstream file gets an entry in `docs/PATCHES.md`: file, why, upstream-submission status (`local-only` / `submitted` / `merged-upstream` / `rejected-upstream`).
- **BR-25.** Preferred order of intervention: (1) new file in a new directory; (2) new file in an upstream directory using an existing extension point; (3) minimal edit to an upstream file. Each step down requires justification in `PATCHES.md`.
- **BR-26.** The full delta vs. base is reproducible as `git diff <base>..HEAD -- engine/` and published per release (BR-12).

## 5. Upstream sync process (`scripts/sync-upstream.sh`)

1. Fetch upstream; identify the new release tag.
2. On branch `sync/<tag>`: `git subtree pull --squash --prefix=engine <remote> <tag>`.
3. Resolve conflicts — conflicts should be confined to files listed in `PATCHES.md`; a conflict elsewhere means the patch-isolation policy was violated: fix the policy breach, not just the conflict.
4. Update `UPSTREAM_VERSION.md`; run the full CI matrix; run the T-GAME smoke set on hardware.
5. Merge via PR titled `sync: OpenTTD <tag>`; never mix sync PRs with feature work.

Cadence: within two weeks of every upstream stable release; the weekly `upstream-drift.yml` CI run gives early warning of conflicts (R-03).

## 6. This repository today

`OpenTTDPad` currently contains only `/docs`. The first engineering commits (Phase 0) add `engine/` (subtree), `cmake/`, `scripts/`, and `os/ios/` per this layout. The repo `LICENSE` becomes GPLv2 when the engine subtree lands (the PRD documents themselves are © the project, licensed CC-BY-4.0 unless the maintainer chooses otherwise — record the choice in the root LICENSE alongside the GPL when code lands).
