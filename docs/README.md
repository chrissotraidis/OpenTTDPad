# OpenTTD for iPadOS — PRD Documentation Suite

**Product name:** OpenTTD for iPadOS
**Repository:** `OpenTTDPad`
**Research snapshot date:** July 19, 2026
**Engine foundation:** current upstream OpenTTD source (stable 15.3 at research time; re-verify at build time — see [00-builder-instructions.md](00-builder-instructions.md))
**Verdict:** Strong go. P0.0 and P0.1 are complete; iOS feasibility remains
subject to P0.2–P0.4 and Gate G0.

This directory is the complete, authoritative Product Requirements Documentation for building a native iPadOS port of OpenTTD. It is written to be executed by an autonomous builder agent or a human engineering team with no other context.

---

## Document index and reading order

| # | Document | Contents | Primary audience |
|---|----------|----------|------------------|
| 00 | [Builder instructions](00-builder-instructions.md) | Prime directives, execution order, verification rules, commit conventions, stop conditions | Builder agent — **read first** |
| 01 | [Product requirements](01-product-requirements.md) | Vision, goals, non-goals, users, functional requirements FR-1…FR-12, non-functional requirements NFR-* | Everyone |
| 02 | [Technical architecture](02-architecture.md) | Layer diagram, native shell, SDL layer, rendering, main loop, threading, input pipeline, ADRs | Engineers |
| 03 | [Touch interaction spec](03-touch-interaction.md) | Gesture catalog TI-*, gesture state machine, tunable constants, precision mode, UI scaling, touch settings | Engineers, designers |
| 04 | [Pointer and keyboard spec](04-pointer-keyboard.md) | Mouse/trackpad/keyboard requirements PK-*, input-mode switching, key mapping | Engineers |
| 05 | [Content and onboarding](05-content-onboarding.md) | First-launch flow, free base sets, TTD asset importer, online content, Files app integration CO-* | Engineers |
| 06 | [Saves and lifecycle](06-saves-lifecycle.md) | Sandbox paths, save management, iCloud (deferred), app lifecycle SL-*, multiplayer lifecycle, device changes | Engineers |
| 07 | [Build system and CI](07-build-and-ci.md) | CMake iOS toolchain, two-stage host-tools build, dependencies, scripts, Xcode integration, CI workflows BR-* | Engineers, CI |
| 08 | [Repository strategy](08-repository-strategy.md) | Upstream vendoring, patch policy, directory layout, upstream sync process | Engineers |
| 09 | [Roadmap](09-roadmap.md) | Phases 0–5 with task IDs P\<phase\>.\<n\>, acceptance criteria, effort, decision gates G0–G5, go/no-go experiments EXP-1…EXP-10 | Everyone |
| 10 | [Testing plan](10-testing.md) | Device matrix, input matrix, test catalog T-*, lifecycle and performance tests | QA, engineers |
| 11 | [Licensing and distribution](11-licensing-distribution.md) | GPLv2 compliance checklist, base-set license audit, distribution channels, App Store conditions | Everyone |
| 12 | [Risk register](12-risks.md) | Risks R-01…R-12 with probability, impact, detection, mitigation | Everyone |
| 13 | [Success metrics](13-metrics.md) | Alpha / beta / release exit criteria and how each is measured | Everyone |
| 14 | [Glossary](14-glossary.md) | OpenTTD and Apple-platform terminology | Everyone |

## Active implementation records

| Document | Purpose |
|---|---|
| [IMPLEMENTATION_GOAL.md](IMPLEMENTATION_GOAL.md) | Goal-based autonomous builder prompt and proof loop |
| [UPSTREAM_FACTS.md](UPSTREAM_FACTS.md) | Live versions, architecture facts, content checksums, and license audit |
| [STATUS.md](STATUS.md) | Roadmap state, environment, commands, evidence, and experiment ledger |
| [REFERENCE_SOURCES.md](REFERENCE_SOURCES.md) | Rules and manifest for the gitignored `ref/` workspace |
| [PATCHES.md](PATCHES.md) | Required log of edits to pre-existing upstream engine files |
| [DEVIATIONS.md](DEVIATIONS.md) | Maintainer-approved deviations from binding requirements |

## Requirement and task ID conventions

Every normative statement in this suite carries a stable ID so a builder can reference, implement, and verify it mechanically:

- `FR-#` — functional requirement (doc 01)
- `NFR-<AREA>-#` — non-functional requirement (doc 01)
- `TI-#` — touch interaction requirement (doc 03)
- `PK-#` — pointer/keyboard requirement (doc 04)
- `CO-#` — content/onboarding requirement (doc 05)
- `SL-#` — saves/lifecycle requirement (doc 06)
- `BR-#` — build/repository requirement (docs 07–08)
- `MP-#` — multiplayer requirement (docs 01, 06)
- `P<phase>.<n>` — roadmap task, e.g. `P0.3` (doc 09)
- `G<phase>` — decision gate at end of a phase (doc 09)
- `EXP-#` — go/no-go experiment (doc 09)
- `T-<AREA>-#` — test case (doc 10)
- `R-##` — risk (doc 12)
- `ADR-###` — architecture decision record (doc 02)

The words **shall** (mandatory), **should** (strongly recommended, deviation must be documented), and **may** (optional) are used in the RFC 2119 sense.

## Scope summary

The smallest defensible 1.0 release is:

- native arm64 iPad application (no browser, no emulation, no JIT)
- free base graphics and sound bundled or auto-installed; playable offline on first launch
- full single-player game loop
- usable touch-only controls, plus full desktop-grade mouse/trackpad/keyboard input
- save import/export through the Files app, desktop-compatible
- reliable background/resume behavior
- reproducible source build with published corresponding source

Explicitly deferred past 1.0: iCloud sync, Stage Manager resizing, external displays, multiplayer, App Store distribution (conditional), portrait orientation, multiple windows. See [01-product-requirements.md](01-product-requirements.md) §4.

## Fact freshness

Version numbers, upstream file names, license terms, and Apple-platform behaviors cited in these documents reflect the July 19, 2026 research snapshot. Task **P0.0** in the roadmap requires the builder to re-verify every load-bearing external fact against live upstream sources before acting on it, and to record corrections in `docs/UPSTREAM_FACTS.md`.
