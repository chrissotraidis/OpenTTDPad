# OpenTTDPad — OpenTTD for iPadOS

A native, touch-first iPadOS adaptation of the current upstream [OpenTTD](https://www.openttd.org) engine: touch-first controls, desktop-quality pointer and keyboard input, desktop-compatible saves, online content, and a reproducible open-source build.

> **Status: full native Simulator and unsigned device builds are working.**
> The touch-first app includes audited free assets, desktop-compatible saves,
> Files import/export, persistent touch settings, verified HTTPS content,
> international text, and native MIDI playback. The automated touch/lifecycle
> suite passes all 18 invocations across Pro, base, and mini iPad Simulators.
> Physical-device input,
> thermal, and lifecycle gates remain open. See
> [docs/STATUS.md](docs/STATUS.md).

## What this project is

- A native iPadOS **platform port** of upstream OpenTTD (no browser wrapper, no emulation)
- An iPad **interaction and usability layer** (direct touch, precision mode, gesture routing)
- An **upstream-tracking distribution** with a small, documented patch set
- Fully playable with **free base content** (OpenGFX / OpenSFX / OpenMSX) — no Transport Tycoon Deluxe purchase required

## What this project is not

- A recreation or redesign of the OpenTTD simulation
- An official upstream release (OpenTTD does not currently ship an iOS/iPadOS target)
- A bundle of copyrighted Transport Tycoon Deluxe assets — those are never committed here

## Documentation

Start at [docs/README.md](docs/README.md) — it indexes the full PRD suite and defines the reading order for human contributors and autonomous builder agents alike.

Active implementation records:

- [Autonomous implementation goal](docs/IMPLEMENTATION_GOAL.md)
- [Verified upstream facts and content licenses](docs/UPSTREAM_FACTS.md)
- [Progress, commands, experiments, and evidence](docs/STATUS.md)
- [Local reference-source policy](docs/REFERENCE_SOURCES.md)
- [Downstream engine patch log](docs/PATCHES.md)
- [Requirement deviations](docs/DEVIATIONS.md)

## Build the iPad Simulator app

```sh
./scripts/bootstrap-ios.sh
./scripts/run-simulator.sh
```

The bootstrap keeps all downloaded sources and game archives under the
gitignored `ref/` tree. The build uses native host generators, then produces
arm64 Simulator libraries and the signed local `.app` under `build/`.

For an unsigned arm64 physical-device bundle (installation still requires your
own signing identity), run `./scripts/build-device.sh`. Then create a checksummed
unsigned IPA with `./scripts/package-ipa.sh` and verify release hygiene with
`./scripts/verify-release.sh`.

## Licensing

OpenTTD is licensed under the GNU GPL v2. All engine code that eventually lands in this repository will carry that license, with complete corresponding source published for every distributed binary. See [docs/11-licensing-distribution.md](docs/11-licensing-distribution.md).
