# 14 — Glossary

| Term | Meaning |
|------|---------|
| **OpenTTD** | Open-source transport simulation based on Transport Tycoon Deluxe; GPLv2; the upstream engine this project ports |
| **TTD** | Transport Tycoon Deluxe (1995), the commercial original; its assets are optional and never bundled |
| **Base set** | The graphics, sound, or music package OpenTTD needs to run (free: OpenGFX/OpenSFX/OpenMSX; original: TTD files) |
| **OpenGFX / OpenSFX / OpenMSX** | The free replacement graphics / sound / music base sets |
| **GRF / NewGRF** | OpenTTD's add-on format for graphics/vehicles/industries; downloadable in-game |
| **BaNaNaS** | OpenTTD's online content service (NewGRFs, scenarios, heightmaps, AIs, scripts, base sets) |
| **Game Script / AI** | Squirrel-language server-side scripts and computer-controlled companies |
| **Scenario (`.scn`) / heightmap** | Prebuilt map / grayscale elevation image for map generation |
| **`.sav`** | OpenTTD save file; upstream guarantees newer versions load older valid saves |
| **`openttd.cfg` / `hotkeys.cfg`** | Engine configuration / keyboard-binding files |
| **SDL2** | Cross-platform media layer providing window, rendering surface, audio, and input on iOS |
| **Synthetic mouse events** | Mouse events an OS/SDL fabricates from touches (suppressed here; see PK-2) |
| **`TouchInputTranslator`** | This project's gesture-to-engine-input layer (docs 02/03) |
| **Precision mode** | Long-press loupe with crosshair for exact tile/control targeting (TI-20…24) |
| **Scene lifecycle** | iPadOS `UIScene`-based app lifecycle; required for apps built with the iOS/iPadOS 27 SDK |
| **Stage Manager** | iPadOS windowing mode with resizable app windows (Phase 4) |
| **Safe area** | Screen region free of corners, camera housing, and home indicator |
| **`UIApplicationSupportsIndirectInputEvents`** | Info.plist key enabling genuine mouse/trackpad events |
| **Security-scoped resource** | Sandbox mechanism for reading user-picked external files |
| **Subtree / vendoring** | Keeping a pinned copy of upstream inside this repo (ADR-003) |
| **Corresponding source** | The exact source (with build scripts) for a distributed GPL binary |
| **Sideloading / AltStore / SideStore** | Installing an IPA outside the App Store |
| **TestFlight** | Apple's beta-distribution service (license review required first) |
| **IPA** | iOS app package (the distributable archive) |
| **JIT** | Just-in-time code generation; forbidden on iOS and not needed here |
| **Gate (G0–G5)** | Phase-exit decision point in the roadmap |
| **EXP-1…10** | The go/no-go experiments (doc 09 §8) |
