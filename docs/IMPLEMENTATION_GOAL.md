# OpenTTDPad autonomous implementation goal

This is the working prompt for the builder. The numbered PRD documents remain
authoritative; this file turns them into an execution loop with explicit proof.

## Objective

Build the definitive native, unofficial OpenTTD experience for iPadOS from the
current stable upstream engine. Deliver a reproducible arm64 device and arm64
Simulator build, freely playable offline, with direct touch controls that feel
designed for iPad, full mouse/trackpad/keyboard parity, desktop-compatible
saves, resilient lifecycle behavior, online content, complete corresponding
source, and auditable third-party notices.

## Non-negotiable boundaries

- Use official upstream OpenTTD 15.3 at commit
  `14ec60f248547d4d062a1160f0fc26d742319888` as the initial engine base.
- Never modify simulation rules, save format, economy, pathfinding, map
  generation, or multiplayer determinism.
- Never commit or distribute original Transport Tycoon Deluxe assets.
- Keep all downloaded research checkouts, build probes, archives, and local
  game files under the gitignored `ref/` directory.
- Reimplement touch behavior against upstream extension points. Do not transplant
  obsolete iOS/Android fork code.
- Prefer new isolated platform/touch files. Log every edit to a pre-existing
  upstream file in `docs/PATCHES.md`.
- Do not begin Phase 2 touch-product work until Gate G0 has passed.
- Never claim Simulator automation proves physical multitouch, Pencil, pointer
  feel, thermal behavior, or physical-device lifecycle reliability.

## Definition of done

The project is done only when Gates G0 through G5 in `09-roadmap.md` are closed
with evidence and the public-release metrics in `13-metrics.md` are green.
Version 1.0 must include:

1. Native arm64 iPad launch with no browser, emulator, JIT, or private API.
2. Offline first launch with audited free graphics and sound.
3. Full single-player loop and unmodified desktop-compatible saves.
4. Touch-only completion of the complete `T-GAME` core loop.
5. Precision mode meeting the 80% first-attempt target in structured trials.
6. Desktop-quality mouse, trackpad, hardware keyboard, and software keyboard.
7. Atomic saves and ten clean background/foreground cycles on hardware.
8. Files import/export, settings persistence, lifecycle recovery, and content
   downloads.
9. Clean-clone bootstrap, macOS validation, Simulator build, unsigned device
   build, forbidden-asset scan, and license inventory in CI.
10. Exact source-to-binary provenance, GPLv2 corresponding source, patch log,
    checksums, and in-app notices.

## Execution loop

For each roadmap task:

1. Read the linked requirements and acceptance tests before editing.
2. Record the smallest architecture decision needed; do not generalize early.
3. Implement the smallest reversible slice that can prove the requirement.
4. Add host-runnable unit/integration coverage where possible.
5. Build macOS validation and all iOS targets currently in scope.
6. Run the named test cases and capture command logs or isolated screenshots.
7. Test the real interaction in Simulator; repeat after every input/UI change.
8. Keep physical-device-only checks open until demonstrated on hardware.
9. Update `STATUS.md`, `PATCHES.md`, facts, deviations, and affected PRD text in
   the same change.
10. Stop at a failed gate and write a report in `docs/reports/`; never paper
    over a failed experiment.

## Touch quality bar

Touch is a product system, not mouse emulation. The implementation must include
direct taps, tool-aware one-finger construction, universal two-finger pan,
midpoint-anchored pinch zoom, deliberate drag thresholds, secondary action,
double tap, momentum only for viewport movement, expanded 44 pt touch hit
regions, safe-area-aware layout, cancel/abort affordances, touch hints, haptics,
independent UI/font/hit-area/world scales, and a long-press precision loupe with
snapping and cancellation.

Every gesture state and threshold boundary gets deterministic host tests. Every
gesture also has a button, menu, or keyboard path. Simulator passes cover visual
layout, taps, text, lifecycle, pointer/keyboard basics, and scripted event
injection where supported. Sustained multitouch, Pencil, physical pointer feel,
latency, thermal, audio-route, and device backgrounding remain hardware gates.

## Current checkpoint

- P0.0 fact re-verification: complete on 2026-07-18.
- P0.1 macOS baseline: complete; Release build and 96/96 tests passed, free
  assets loaded, deterministic game saved and visibly reopened.
- P0.2 iOS toolchain: next. Vendor the pinned engine subtree, build native host
  tools, pin SDL 2.32.10, and establish arm64 Simulator/device dependency builds.
