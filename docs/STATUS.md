# Implementation status

Updated: **2026-07-18**

## Environment

- Hardware: Apple Silicon (`arm64`), MacBook Air 10,1
- macOS: 26.5.2 (25F84)
- Xcode: 26.6 (17F113)
- iPhoneOS / Simulator SDK: 26.5 / 26.5
- Simulator runtimes: iOS 18.5 and 26.5; required iPad Pro, Air, base iPad,
  and mini profiles are installed
- Apple Clang: 21.0.0
- CMake: 4.4.0; Ninja: 1.13.2; Homebrew: 6.x; GitHub CLI: 2.93.0
- Physical iPad: not yet connected or verified; every hardware-only experiment
  remains open

## Roadmap

- [x] P0.0 — fact re-verification — done 2026-07-18 — see
  `UPSTREAM_FACTS.md`
- [x] P0.1 — macOS baseline — done 2026-07-18 — OpenTTD 15.3 Release build,
  96/96 tests, verified free content, deterministic save/reload
- [ ] P0.2 — iOS toolchain build — in progress
- [ ] P0.3 — SDL iOS first frame
- [ ] P0.4 — input probe
- [ ] Gate G0 — blocked on P0.2–P0.4 and physical-device experiments
- [ ] Phases 1–5 — not started by design

## P0.1 evidence

Configuration and build:

```sh
cmake -S ref/OpenTTD -B ref/OpenTTD/build-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DOPTION_USE_ASSERTS=ON
cmake --build ref/OpenTTD/build-macos --parallel 8
ctest --test-dir ref/OpenTTD/build-macos --output-on-failure
```

Result: Release executable linked successfully. `ctest` passed **96/96** in
112.21 seconds.

Content verification:

```sh
shasum -a 256 ref/game-files/*.zip
ref/OpenTTD/build-macos/openttd -X -h
```

Result: all CDN checksums matched `UPSTREAM_FACTS.md`; the isolated build found
OpenGFX 8.0, OpenSFX 1.0.3, and OpenMSX 0.4.2.

Save proof:

```text
Map successfully saved to
'/Users/chrissotraidis/GitHub/OpenTTDPad/ref/game-files/baseline-p0.sav.sav'.
```

The save is 81 KiB, reports savegame version 362, and was visibly reopened by
the packaged 15.3 app:

- [deterministic new game](evidence/p0-macos-new-game.png)
- [reopened baseline save](evidence/p0-macos-reloaded-save.png)

Packaging note: CPack's Bundle generator successfully assembled `OpenTTD.app`
but the final DMG step could not attach an HFS+ image in this environment.
CPack also rewrites bundled dylib install names after their original signing;
explicitly signing inner dylibs, then the executable, then the outer app made
the local bundle valid and launchable. This does not affect the engine build.

## Experiment ledger

| Experiment | State | Evidence / remaining gate |
|---|---|---|
| EXP-1 iOS arm64 compile | Pending | P0.2 |
| EXP-2 visible iPad window | Pending | Simulator plus physical iPad required |
| EXP-3 software rendering | Partial | macOS gameplay rendered; iPad performance pending |
| EXP-4 free content | Partial | verified and loaded on macOS; iPad bundle pending |
| EXP-5 sandbox writes | Partial | local deterministic save/reload passed; iPad sandbox pending |
| EXP-6 physical pointer | Pending | physical iPad hardware required |
| EXP-7 touch separation | Pending | P0.4 |
| EXP-8 software keyboard | Pending | P0.4 |
| EXP-9 lifecycle loop | Pending | physical iPad required |
| EXP-10 touch construction | Pending | Phase 2 usability trials |

## Current next proof

Vendor the exact 15.3 engine base into `engine/`, preserve GPLv2 provenance,
generate native host tools, build pinned SDL 2.32.10 and minimum static
dependencies for arm64 Simulator/device, and close EXP-1 before shell or touch
product work expands.
