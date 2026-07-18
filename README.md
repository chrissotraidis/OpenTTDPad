# OpenTTDPad — OpenTTD for iPadOS

A native, touch-first iPadOS adaptation of the current upstream [OpenTTD](https://www.openttd.org) engine: touch-first controls, desktop-quality pointer and keyboard input, desktop-compatible saves, online content, and a reproducible open-source build.

> **Status: specification phase.** No engine code lives in this repository yet. The complete, builder-ready Product Requirements Documentation is in [`/docs`](docs/README.md). The engineering work begins with the Phase 0 feasibility spike defined in [docs/09-roadmap.md](docs/09-roadmap.md).

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

## Licensing

OpenTTD is licensed under the GNU GPL v2. All engine code that eventually lands in this repository will carry that license, with complete corresponding source published for every distributed binary. See [docs/11-licensing-distribution.md](docs/11-licensing-distribution.md).
