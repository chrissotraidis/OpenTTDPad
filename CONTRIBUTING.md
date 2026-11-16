# Contributing to OpenTTDPad

Thanks for helping. OpenTTDPad keeps OpenTTD's simulation, rules and save format
unchanged and adds the iPad layer around them, so most changes live in
`engine/src/os/ios/`, `engine/src/touch/`, `engine/src/video/sdl2_v.cpp` and
`scripts/`.

## The most useful contributions

- **Reports from real iPads.** Device model, iPadOS version, what you did, what
  happened, and a screenshot. Crash logs are in Files → On My iPad → OpenTTDPad →
  OpenTTD. Use the [bug report form](https://github.com/chrissotraidis/OpenTTDPad/issues/new/choose).
- **Touch and layout fixes** with a host test in `engine/src/tests/gesture_state.cpp`
  or an XCTest scenario in `tests/ios-ui/`.
- **Documentation** that makes building or installing easier.

## Building

You need an Apple Silicon Mac with Xcode, CMake, Ninja and about 10 GB free.

```sh
./scripts/bootstrap-reference.sh   # pinned sources and free content, once
./scripts/build-simulator.sh && ./scripts/run-simulator.sh booted
./scripts/build-device.sh && ./scripts/package-ipa.sh
```

## Before opening a pull request

```sh
./scripts/check-local.sh          # hygiene, host tests, Simulator UI tests, device build
./scripts/check-local.sh --quick  # hygiene and host tests only
```

- Keep changes narrow and preserve upstream gameplay and save behaviour.
- Record every edit to a file inherited from OpenTTD in [`docs/PATCHES.md`](docs/PATCHES.md).
- Never commit downloaded sources, game data or anything from `ref/`. Original
  Transport Tycoon Deluxe files are never accepted.
- OpenTTDPad is GPLv2. By contributing you agree your work is released under it.

Gameplay bugs that also happen in desktop OpenTTD belong upstream at
[OpenTTD/OpenTTD](https://github.com/OpenTTD/OpenTTD/issues).
