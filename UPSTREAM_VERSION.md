# Upstream version

OpenTTDPad currently tracks the following immutable upstream engine base:

- Repository: <https://github.com/OpenTTD/OpenTTD.git>
- Release tag: `15.3`
- Upstream commit: `14ec60f248547d4d062a1160f0fc26d742319888`
- Imported path: `engine/`
- Import method: `git subtree --squash`
- Squashed source commit: `dcc2a9413c8a4783d8c2266f4ee84dc928f740e9`
- Subtree merge commit: `e9c31690428bbb1ec066a9f12b031a0460de9b6c`
- Import date: 2026-07-18
- Generated-version input: `engine/.ottdrev` reports release `15.3`, the exact
  upstream hash/date, tagged/stable state, and downstream-modified state `2`.

Downstream changes to files that existed at this upstream commit are recorded
in [`docs/PATCHES.md`](docs/PATCHES.md). A future upstream update must refresh
this file, rerun the upstream macOS baseline, and pass every gate in
[`docs/10-testing.md`](docs/10-testing.md).
