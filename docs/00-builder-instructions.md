# 00 — Builder Instructions

Operating manual for the autonomous builder agent (or human lead) executing this PRD. Read this document completely before touching any code.

---

## 1. Prime directives

1. **Foundation is upstream OpenTTD.** Build on the current upstream OpenTTD source. Never base the project on the obsolete native iOS fork, the Android fork's source tree, a WebAssembly wrapper, or the original Transport Tycoon Deluxe executable ([ADR-001](02-architecture.md)). The Android fork may be *read* for interaction ideas; its code must not be copied wholesale (see directive 6 and [R-11](12-risks.md)).
2. **Never commit copyrighted assets.** Original Transport Tycoon Deluxe files (`TRG*.GRF`, `SAMPLE.CAT`, GM music files, or any derivative) must never enter this repository, its history, its CI artifacts, or any distributed binary. The `.gitignore` enforces the common filenames; the directive covers everything else.
3. **Do not modify simulation logic.** The port changes platform, input, rendering-host, and UI-hit-testing code only. Any change that could alter simulation outcomes (economy, pathfinding, vehicle behavior, map generation, save format) is out of scope and breaks multiplayer/save compatibility ([NFR-REL-5](01-product-requirements.md)).
4. **Keep the patch set small and isolated.** New code goes in dedicated iOS/touch directories. Edits to existing upstream files must be minimal, individually justified, and logged in `docs/PATCHES.md` ([08-repository-strategy.md](08-repository-strategy.md) §4).
5. **GPLv2 compliance is non-negotiable.** Every distributed binary must have published corresponding source for that exact binary, all license texts, and clear identification of modifications ([11-licensing-distribution.md](11-licensing-distribution.md)).
6. **Reimplement, don't transplant.** Concepts proven elsewhere (e.g. the Android fork's pinch-to-zoom thresholds) are specified in this PRD as requirements; implement them fresh against current upstream code.
7. **Verify before you claim.** A task is done only when its acceptance criteria have been demonstrated (build output, test run, on-device check) — not when the code compiles.

## 2. Order of execution

Execute the roadmap ([09-roadmap.md](09-roadmap.md)) strictly in phase order. Within a phase, respect the dependency notes on each task; otherwise tasks may be parallelized.

```
P0.0 fact re-verification
  └─► P0.1 macOS baseline ─► P0.2 iOS toolchain ─► P0.3 first frame ─► P0.4 input probe ─► GATE G0
        Phase 1 (functional native build) ─► GATE G1
          Phase 2 (touch MVP) ─► GATE G2
            Phase 3 (productization) ─► GATE G3
              Phase 4 (desktop-quality input, advanced iPad) ─► GATE G4
                Phase 5 (multiplayer + release) ─► GATE G5
```

**Do not begin Phase 2 interface work before Gate G0 passes.** The whole point of the spike is to avoid investing in UX on top of an unproven native build.

## 3. Fact re-verification (task P0.0)

This PRD was researched on July 19, 2026. Before acting, verify each of the following against live sources and record findings (with URLs and dates) in `docs/UPSTREAM_FACTS.md`:

| Fact to verify | Research-time value | Where to check |
|---|---|---|
| Current stable OpenTTD release/tag | 15.3 (2026-04-04) | github.com/OpenTTD/OpenTTD releases |
| Current testing branch | 16.0-beta2 | same |
| Minimum CMake version | 3.17 | upstream 15.3 `CMakeLists.txt`; reverified in `UPSTREAM_FACTS.md` |
| C++ standard required | C++20 | upstream `CMakeLists.txt` |
| SDL major version used by upstream | SDL2 (`src/video/sdl2_v.cpp`, `sdl2_default_v.cpp`, `sdl2_opengl_v.cpp`) | upstream `src/video/` |
| Upstream finger-event handling | none (`SDL_FINGERDOWN/UP/MOTION` not handled) | upstream SDL video driver |
| Host-tool cross-compile mechanism (used by emscripten build) | host tools built separately, handed to cross build | upstream `cmake/` and `os/emscripten/` |
| OpenGFX / OpenSFX / OpenMSX licenses and notice requirements | GPLv2 / audit required / GPLv2 (audit all) | each base set's repository |
| Apple scene-lifecycle requirement | required for apps built with iOS/iPadOS 27 SDK | Apple developer documentation |
| Current Xcode / iOS SDK versions | Xcode 16.x-era at research time | developer.apple.com |
| SDL iOS indirect-input support (`UIApplicationSupportsIndirectInputEvents`) | supported | SDL docs/source |

If a verified fact contradicts this PRD, the verified fact wins; note the divergence in `UPSTREAM_FACTS.md` and, where it changes a requirement, in `docs/DEVIATIONS.md`.

## 4. Decision gates and stop conditions

Stop work and produce a written report (rather than improvising) when:

- A **gate** (G0–G5) fails its criteria — see [09-roadmap.md](09-roadmap.md) §Gates.
- **EXP-1 through EXP-4 fail**: this is a technical no-go or architecture reset; escalate with the failure evidence.
- A change would require **modifying simulation logic** (directive 3).
- A change would require **bundling non-free content** (directive 2).
- SDL's iOS backend proves unable to present the game surface without **replacing major rendering or application-loop systems** (Task P0.3 decision gate).
- A legal/licensing question arises that this PRD does not already answer.

The report goes in `docs/reports/<date>-<topic>.md`: what was attempted, evidence, options, recommendation.

## 5. Working conventions

### Progress tracking
Maintain `docs/STATUS.md` as a live checklist: one line per roadmap task (`P0.1 — done 2026-07-21 — commit abc1234`) and per experiment (`EXP-6 — pass — video/log link`). Update it in the same commit as the work it records.

### Commits
- One logical task (or coherent sub-task) per commit; reference the task ID in the subject: `P1.2: implement lifecycle bridge (background/foreground)`.
- Never mix upstream-sync commits with feature commits.
- Never rewrite published history on `main`.

### Branches and merges
- `main` is always releasable-doc / buildable-code state.
- Work on `feat/<task-id>-<slug>` branches; merge via PR with the phase acceptance evidence in the PR body.

### Deviations
Any deliberate deviation from a **shall** requirement gets an entry in `docs/DEVIATIONS.md`: requirement ID, what was done instead, why, approved-by.

### Documentation upkeep
When code changes make a spec statement false, fix the spec in the same PR. The docs in this folder are the source of truth; stale truth is a defect.

## 6. Environment prerequisites

The builder must confirm (and record versions in `STATUS.md`):

- Apple Silicon Mac, current macOS
- Current Xcode with iOS SDK, command-line tools installed (`xcode-select -p` resolves)
- CMake at or above upstream's minimum (verify per §3)
- git; `gh` CLI for PR automation
- An Apple ID for device signing (a free account suffices for 7-day development installs; a paid account is needed for TestFlight later)
- At least one physical arm64 iPad for device testing (Simulator alone cannot satisfy EXP-2/EXP-6/EXP-9)
- Optional: vcpkg, if the dependency strategy in [07-build-and-ci.md](07-build-and-ci.md) §3 selects it

## 7. Definition of done (applies to every task)

A task is complete when all of the following hold:

1. Its listed acceptance criteria are demonstrated with evidence (command output, screenshot, screen recording, or test log) linked from `STATUS.md`.
2. The code builds for every target that CI covers at that phase (macOS validation + iOS targets once they exist).
3. New behavior has a corresponding test or documented manual test procedure in [10-testing.md](10-testing.md).
4. `PATCHES.md` is updated if any upstream file was touched.
5. Docs affected by the change are updated (see §5).
6. No prohibited content (directive 2) is present in the diff.
