<p align="center">
  <img src="os/ios/AppIcon.png" alt="OpenTTDPad app icon: the OpenTTD logo" width="148">
</p>

<h1 align="center">OpenTTDPad</h1>

<p align="center">
  <strong>OpenTTD, native on iPad.</strong><br>
  Railways, roads, ships and planes, built with your fingers. Touch-first construction, a precision loupe,
  Apple Pencil, trackpad and keyboard, desktop-compatible saves, and free graphics, sound and music.
</p>

<p align="center">
  <a href="https://github.com/chrissotraidis/OpenTTDPad/releases/tag/v0.2.0"><img alt="Release 0.2.0 preview" src="https://img.shields.io/badge/release-0.2.0%20preview-FF9F0A"></a>
  <img alt="iPadOS 17 or later" src="https://img.shields.io/badge/iPadOS-17%2B-0A84FF?logo=apple">
  <img alt="OpenTTD 15.3" src="https://img.shields.io/badge/OpenTTD-15.3-F28C28">
  <img alt="Native ARM64" src="https://img.shields.io/badge/runtime-native%20ARM64-30D158">
  <img alt="iPadOS 27 checked on a physical iPad" src="https://img.shields.io/badge/iPadOS%2027-physical%20iPad%20checked-30D158">
  <img alt="Original TTD data not required" src="https://img.shields.io/badge/original%20TTD%20data-not%20required-8E8E93">
  <a href="LICENSE"><img alt="License: GPLv2" src="https://img.shields.io/badge/license-GPLv2-8E8E93"></a>
  <a href="https://github.com/chrissotraidis/padmint"><img alt="Build with PadMint" src="https://img.shields.io/badge/PadMint-build%20your%20own-3EB489"></a>
  <a href="https://discord.gg/xwHfUD2bxW"><img alt="Join the community on Discord" src="https://img.shields.io/badge/Discord-Join%20the%20community-5865F2?logo=discord&amp;logoColor=white"></a>
</p>

<p align="center">
  <a href="#get-openttdpad"><strong>Get OpenTTDPad</strong></a> ·
  <a href="#controls">Controls</a> ·
  <a href="#a-look-around">Screenshots</a> ·
  <a href="#current-status">Status</a> ·
  <a href="#frequently-asked-questions">FAQ</a>
</p>

<p align="center">
  <img src="docs/readme/hero-railway-town.jpg" alt="A busy OpenTTD rail network with a station, canals and trains, running full screen on iPad" width="920">
</p>

OpenTTDPad is an unofficial iPadOS port of [OpenTTD](https://www.openttd.org/),
the open-source transport simulation based on Transport Tycoon Deluxe. The
OpenTTD 15.3 simulation, economy, pathfinding and save format are untouched.
OpenTTDPad adds what an iPad needs: a gesture system that turns fingers into
OpenTTD actions, controls that stay out of the way, Files integration, native
MIDI music, international text, verified HTTPS for Online Content, and
reproducible builds.

> [!IMPORTANT]
> **0.2.0 is the first public preview.** [Download the unsigned IPA](https://github.com/chrissotraidis/OpenTTDPad/releases/tag/v0.2.0)
> and sign it yourself, build it with [PadMint](https://github.com/chrissotraidis/padmint),
> or build from source. It runs on a physical iPad Pro 12.9-inch (6th
> generation) with iPadOS 27.2.1. Pencil, trackpad, keyboard, external displays
> and long sessions have not been checked on hardware yet. See
> [Current status](#current-status) and the [0.2.0 release notes](docs/releases/v0.2.0.md).

## Highlights

<table>
  <tr>
    <td width="50%"><img src="docs/readme/touch-construction.jpg" alt="Railway Construction toolbar open with the compact Cancel button in the corner"></td>
    <td width="50%"><img src="docs/readme/title-menu.jpg" alt="The OpenTTD title screen and main menu on iPad"></td>
  </tr>
  <tr>
    <td valign="top"><strong>Build with your fingers.</strong> Pick a tool and drag to lay track, road or canal. A second finger or the Cancel button stops the tool without a stray placement.</td>
    <td valign="top"><strong>All of OpenTTD.</strong> Every game mode, the scenario editor, AI opponents, multiplayer and Online Content, with the free OpenGFX, OpenSFX and OpenMSX sets built in.</td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/readme/options-menu.jpg" alt="The OpenTTDPad options menu opening below the toolbar's Help button"></td>
    <td width="50%"><img src="docs/readme/about-page.jpg" alt="The About OpenTTDPad page with version, links and credits"></td>
  </tr>
  <tr>
    <td valign="top"><strong>Out of the way.</strong> The ⋯ button sits under the toolbar's Help button for saves, Files, touch settings and About. It steps aside when a game window docks in that corner.</td>
    <td valign="top"><strong>Yours to keep.</strong> Saves are ordinary OpenTTD 15.3 files. Export them all as a ZIP or import saves and content from Files.</td>
  </tr>
</table>

**AI disclosure:** OpenTTDPad uses substantial AI assistance for code, tests,
documentation, debugging and maintenance. There is no audited percentage of
AI-generated code; build, test and device-acceptance records state what has
actually been checked. This describes OpenTTDPad's workflow, not the authorship
of OpenTTD or its other upstream projects.

## What's new in 0.2.0

- **Runs on iPadOS 27.** Earlier test builds opened to a black screen because
  SDL created its window outside the app's UIKit scene. OpenTTDPad now carries
  the same SDL 2.32.10 scene backport as the other Pad ports
  ([`patches/sdl2-ios-scenes.patch`](patches/sdl2-ios-scenes.patch)), so the
  game window follows its scene through rotation, resizing and external displays.
- **Taps land where your finger lands.** Deliberate presses on small targets
  such as window close boxes no longer get dropped or slide off as you lift.
- **The precision loupe shows exactly the spot it will tap.**
- **Tidier controls:** the ⋯ button under the toolbar's Help button, a compact
  Cancel pill, and the OpenTTD logo as the app icon.
- **About OpenTTDPad** with version, links to the source, issues and PadMint,
  credits and every license.

The full list is in the [release notes](docs/releases/v0.2.0.md).

## Get OpenTTDPad

OpenTTDPad needs an iPad on iPadOS 17 or later. Nothing else is required to play:
the free OpenGFX, OpenSFX and OpenMSX content is built in, and no original
Transport Tycoon Deluxe data is downloaded or bundled.

Install updates over the existing app. Deleting OpenTTDPad first also deletes
its saves, settings and downloaded content; export saves from the options menu
first if you must reinstall. The install needs about 65 MB of free space.

<details open>
<summary><strong>Download the unsigned IPA</strong></summary>

Download `OpenTTDPad-unsigned.ipa` from the
[0.2.0 release](https://github.com/chrissotraidis/OpenTTDPad/releases/tag/v0.2.0),
check it against `SHA256SUMS`, and install it with a sideloading tool that signs
it with your own Apple ID, such as [Sideloadly](https://sideloadly.io/) (Mac or
Windows) or [AltStore](https://altstore.io/). Developers can sign it with Xcode
or `devicectl`. The release also carries the complete corresponding source
required by the GPL.

With a free Apple ID, iPadOS stops opening sideloaded apps after seven days.
Reinstall or refresh it over the existing app and your saves stay.

</details>

<details>
<summary><strong>Build it with PadMint</strong></summary>

On an Apple Silicon Mac with Xcode 26 or newer and its iOS platform, choose
**OpenTTDPad** in [PadMint](https://github.com/chrissotraidis/padmint). PadMint
fetches this repository's release, builds the app with the recipe in
[`padmint.json`](padmint.json) and checks the result. There is no game file to
choose. Plan for about 4 GB of free space on the Mac while it builds.

</details>

<details>
<summary><strong>Build from source for a real iPad</strong></summary>

You need an Apple Silicon Mac with Xcode and an iPadOS SDK, CMake, Ninja, Git,
curl and unzip, plus about 10 GB of free space. The bootstrap downloads pinned,
freely redistributable sources and content.

```sh
git clone https://github.com/chrissotraidis/OpenTTDPad.git
cd OpenTTDPad
./scripts/bootstrap-reference.sh
./scripts/build-device.sh
./scripts/package-ipa.sh
./scripts/verify-release.sh
```

The output is `build/artifacts/OpenTTDPad-unsigned.ipa` (the app bundle is
`build/ios-device/openttd.app`). Sign it with your own Apple development
identity and provisioning profile, then install it with Xcode, `devicectl` or
your usual sideloading tool. No credentials or signed binaries are stored in this
repository.

</details>

<details>
<summary><strong>Run it in the iPad Simulator</strong></summary>

```sh
./scripts/bootstrap-ios.sh
./scripts/run-simulator.sh booted
```

Boot any iPad Simulator first, or pass its UDID instead of `booted`.

</details>

## Controls

The gesture vocabulary stays small; context does the clever work.

| Gesture | Result |
|---|---|
| Tap | Select, activate or place |
| Drag the map | Pan, with optional momentum |
| Pinch | Zoom around the point between your fingers |
| Two-finger drag | Pan from anywhere, including over windows |
| Double-tap | Perform the default action |
| Drag with a construction tool | Build continuously |
| Drag a window | Move the window, not the map |
| Two-finger tap | Secondary action or details |
| Add a second finger while building | Abort the active tool safely |
| Touch and hold | Open a 132-point precision loupe; move to aim, lift to commit |
| **Cancel** button | End construction without a stray placement |

The **⋯** button just under the toolbar's Help button opens Files (import and
export saves), Touch Controls and About OpenTTDPad.

Undersized OpenTTD controls get touch targets of at least 44 points without
changing their artwork, and controls can be placed for left- or right-handed
reach. Mouse, trackpad, scroll wheel and hardware keyboard keep their normal
OpenTTD behaviour. The full rules are in the
[touch interaction contract](docs/03-touch-interaction.md) and
[pointer and keyboard notes](docs/04-pointer-keyboard.md).

## External displays and iPadOS 27

OpenTTDPad is a single-scene, landscape, full-screen iPad app. The game window
belongs to that scene: when iPadOS mirrors the iPad or Stage Manager moves the
scene to a connected display, SDL resizes the window to the scene's bounds and
the new screen's scale instead of keeping the iPad panel's size. A second
scene, such as a reconnect after a display change, never starts the game a
second time.

This behaviour matches the fix already shipped in the other Pad ports. On
OpenTTDPad it has been checked on the iPad's own display; a physical external
monitor and Stage Manager have not been tested yet.

## Current status

| Area | State |
|---|---|
| Engine | OpenTTD 15.3; gameplay and save compatibility preserved |
| Physical iPad | iPad Pro 12.9" (6th gen), iPadOS 27.2.1: installs, launches, draws the title screen, music, touch input reaches the game |
| Simulator | iOS 27 iPad Pro, iPad and iPad mini: touch, construction, settings, export and lifecycle tests pass |
| Touch | Direct manipulation, tool-aware drags, precision loupe, 44 pt targets, safe cancellation |
| Content | OpenGFX 8.0, OpenSFX 1.0.3, OpenMSX 0.4.2, TimGM6mb MIDI |
| Files | Save import and ZIP export through Files and the share sheet |
| Lifecycle | Scene-based launch, emergency background saves, state recovery |
| Network | Verified HTTPS to OpenTTD's Online Content catalog |
| Text | FreeType, HarfBuzz, ICU and CoreText fallback, including right-to-left scripts |
| Not yet checked on hardware | A full touch-only game, Pencil, trackpad, keyboard, external display, Bluetooth audio, heat and long sessions |

<details>
<summary><strong>Automated checks</strong></summary>

| Check | Result | Last run |
|---|---:|---|
| Untouched upstream macOS baseline | 96 / 96 | 2026-07-24 |
| Host suite, excluding desktop game regressions | 111 / 111 | 2026-07-24 |
| OpenTTDPad host scenarios | 17 / 17 | 2026-07-24 |
| XCTest UI matrix on iOS 27.0 (7 scenarios × 3 iPad classes) | 21 / 21 | 2026-11-15 |

```sh
cmake -S engine -B build/macos -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/macos --parallel 8
ctest --test-dir build/macos --output-on-failure --exclude-regex '^regression_' --timeout 300
./scripts/test-simulator-ui.sh
./scripts/verify-release.sh
```

Simulator automation cannot prove multitouch feel, Pencil or pointer feel,
audio routes, heat, real lifecycle reliability or signing. Those claims stay
open until they are shown on hardware and recorded in
[`docs/STATUS.md`](docs/STATUS.md).

</details>

## A look around

<table>
  <tr>
    <td width="50%"><img src="docs/readme/close-up.jpg" alt="A close-up of a station and trains at the closest zoom level"></td>
    <td width="50%"><img src="docs/readme/online-content.png" alt="OpenTTD Online Content catalog running in OpenTTDPad"></td>
  </tr>
  <tr>
    <td align="center"><strong>Pinch to zoom</strong><br>From the whole map down to single trains</td>
    <td align="center"><strong>Online Content</strong><br>Thousands of free add-ons over verified HTTPS</td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/readme/international-text.png" alt="OpenTTDPad rendering an Arabic right-to-left interface"></td>
    <td width="50%" valign="middle"><strong>International text</strong><br>Every OpenTTD language, including right-to-left scripts, through HarfBuzz, ICU and CoreText fallback fonts.<br><br>Screenshots are from an iOS 27 iPad Pro 13-inch Simulator running the release build with OpenTTD's own title-screen game.</td>
  </tr>
</table>

## Frequently asked questions

### Do I need the original Transport Tycoon Deluxe?

No. OpenTTDPad ships the free OpenGFX graphics, OpenSFX sounds and OpenMSX music,
so a new game works offline straight away. If you own the original game you can
add its data through OpenTTD's normal data folders; it is never bundled here.

### Can I download a ready-made app?

Yes, as an unsigned IPA on the [releases page](https://github.com/chrissotraidis/OpenTTDPad/releases).
iPadOS only installs apps signed for your device, so sign it with your own Apple
ID or developer account, or let PadMint build a copy for you. There is no App
Store version.

### It stopped opening after a week

Apps signed with a free Apple ID expire after seven days. Refresh it in your
sideloading tool, or install the IPA again over the existing app; your saves and
settings are kept. A paid Apple Developer account signs for a year.

### Where are my saves?

In the Files app under **On My iPad → OpenTTDPad → OpenTTD → save**. You can also
use **⋯ → Export All Saves** to share them as one ZIP, and **⋯ → Import Save or
Content** to bring saves, scenarios and heightmaps in.

### The game crashed. What should I send?

Open Files → On My iPad → OpenTTDPad → OpenTTD and attach the newest
`crash….json.log` and its `.png` to a
[bug report](https://github.com/chrissotraidis/OpenTTDPad/issues/new/choose). The
log records where the crash happened and why.

### Are my saves compatible with desktop OpenTTD?

Yes. The save format is OpenTTD 15.3's. Export saves through Files or the share
sheet and open them in desktop OpenTTD 15.3, or import desktop saves the same way.

### Does it run on iPhone?

No. OpenTTDPad targets iPad only, in landscape.

### Does multiplayer work?

OpenTTD's multiplayer code is unchanged, and Online Content downloads work over
verified HTTPS. Joining or hosting a network game from an iPad has not been
tested yet.

### Is this an official OpenTTD release?

No. OpenTTDPad is an independent community port. Report iPad-specific problems
here; report gameplay bugs that also happen on desktop to
[OpenTTD](https://github.com/OpenTTD/OpenTTD/issues).

## Project map

| Path | Purpose |
|---|---|
| `engine/` | Pinned OpenTTD 15.3 plus isolated iOS and touch changes |
| `engine/src/os/ios/` | Scene delegate, overlays, Files, haptics and settings |
| `engine/src/touch/` | Platform-neutral gesture recognizer and hit targets |
| `os/ios/` | App metadata, brand colour and app icon |
| `patches/` | Reproducible patches to pinned SDL sources |
| `scripts/` | Bootstrap, build, package, launch, test and release checks |
| `tests/ios-ui/` | Native XCTest UI scenarios |
| `docs/` | Requirements, architecture, controls, evidence, status and [release notes](docs/releases/) |
| `padmint.json` | PadMint build recipe |
| `ref/` | Gitignored downloaded sources, archives and content |

Start with the [architecture](docs/02-architecture.md), the
[downstream patch log](docs/PATCHES.md) and the
[implementation status](docs/STATUS.md).

## Contributing

The most useful contributions right now are reports from real iPads: device
model, iPadOS version, what you did, what happened, and a screenshot or crash
log. Use the [issue forms](https://github.com/chrissotraidis/OpenTTDPad/issues/new/choose)
or say hello on [Discord](https://discord.gg/xwHfUD2bxW).

For code, read [CONTRIBUTING.md](CONTRIBUTING.md). `./scripts/check-local.sh`
runs the same checks as CI on your Mac.

## License and identity

OpenTTDPad and the OpenTTD engine are distributed under the
[GNU General Public License version 2](LICENSE). Bundled content and libraries
keep their own compatible licenses, recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and the
[distribution audit](docs/11-licensing-distribution.md).

OpenTTDPad is an independent community project. It is not an official OpenTTD
release and is not affiliated with or endorsed by OpenTTD, Transport Tycoon
Deluxe, or their respective rights holders.
