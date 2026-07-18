# 07 — Build System and Continuous Integration

The reproducible-build contract: toolchain, the two-stage cross-compile, dependency strategy, developer scripts, and CI workflows. "Repeatable Xcode and command-line build" is primary goal PG-8.

---

## 1. Baseline facts (verify at P0.0)

Upstream builds with CMake (≥ 3.16 at research time) and a C++20 compiler; the generic flow is `cmake .. && make`. Optional/encouraged dependencies: zlib, liblzma, libpng, libcurl, SDL2, FreeType, HarfBuzz, ICU. Upstream compiles conditional video drivers: SDL2 default and SDL2-OpenGL when SDL2 is present; Cocoa separately for macOS.

## 2. The cross-compilation shape

**BR-1.** OpenTTD's build runs generated host tools (string/settings generators) *during* the build. Cross-compiling therefore uses a **two-stage build**, the same pattern upstream's emscripten target uses:

```bash
# Stage 1 — native macOS host tools
cmake -B build-host -DOPTION_TOOLS_ONLY=ON        # verify current option name upstream
cmake --build build-host --target tools

# Stage 2 — iOS device build, consuming stage-1 tools
cmake -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=<min from doc 01 §8> \
  -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake \
  -DHOST_BINARY_DIR=$PWD/build-host \               # verify current variable name upstream
  ../engine
```

The exact option/variable names for the host-tool handoff must be read from upstream's `cmake/` and emscripten config at P0.2 and recorded in `UPSTREAM_FACTS.md` — do not guess them.

**BR-2.** `cmake/ios.toolchain.cmake` (ours) sets: platform/SDK selection (device vs simulator), arm64-only, minimum OS, bitcode off, signing left to Xcode, and find-root behavior so host libraries never leak into the device build.

**BR-3.** Build targets: iOS Simulator arm64; physical iPad arm64; Debug / RelWithDebInfo / Release configurations; unsigned device archive; unsigned IPA packaging where technically appropriate.

## 3. Dependency strategy

**BR-4.** All third-party libraries are **static** for iOS (no dylib bundling complexity). Two acceptable approaches — P0.2 picks one and records an ADR:

- **Option A — vcpkg** with the `arm64-ios` (and simulator) triplets: upstream already supports vcpkg; gives pinned, manifest-recorded versions.
- **Option B — scripted source builds** of each dependency in `scripts/deps/`, pinned by tag + checksum.

**BR-5.** Dependency tiers for iOS:

| Dependency | Tier | Note |
|---|---|---|
| SDL2 | required | official iOS support; version pinned; build static |
| zlib | required | may use the SDK's zlib |
| liblzma | required | modern desktop saves use it — required for FR-7 |
| libpng | required | heightmaps, screenshots |
| libcurl | required (Phase 3+) | content downloads; confirm whether upstream's HTTP layer needs it on this platform or an NSURLSession shim is cleaner — decide at P3.4 |
| FreeType + HarfBuzz + ICU | deferred-on | off for the spike (sprite fonts suffice); required before release for non-Latin text — enable during Phase 3 |

**BR-6.** A machine-readable dependency manifest (name, version, source URL, checksum, license) is generated into `THIRD_PARTY_NOTICES.md` tooling ([11-licensing-distribution.md](11-licensing-distribution.md)).

## 4. Developer experience

**BR-7.** The documented setup shall be exactly:

```bash
git clone <repository>
cd OpenTTDPad
./scripts/bootstrap-ios.sh
open build/ios/OpenTTD.xcodeproj
```

then: select team → select connected iPad → Run.

**BR-8.** `scripts/bootstrap-ios.sh` shall: verify Xcode + CMake presence and versions; initialize/fetch dependencies (per BR-4 option); fetch or verify pinned SDL2; fetch free base content into the packaging tree (with license audit stamp, CO-3); run both build stages to generate the Xcode project; print signing instructions; and **never modify global system configuration**.

**BR-9.** Script set:

| Script | Responsibility |
|---|---|
| `scripts/bootstrap-ios.sh` | BR-8 |
| `scripts/build-simulator.sh` | clean CLI Simulator build + boot smoke test where possible |
| `scripts/build-device.sh` | clean CLI unsigned device build (`CODE_SIGNING_ALLOWED=NO`) |
| `scripts/package-ipa.sh` | unsigned IPA from the device archive, plus checksums |
| `scripts/sync-upstream.sh` | upstream subtree pull + patch reapply ([08-repository-strategy.md](08-repository-strategy.md) §5) |

All scripts are idempotent and fail loudly with actionable messages.

## 5. Continuous integration (GitHub Actions, macOS runners)

**BR-10.** Required workflows:

| Workflow | Trigger | Jobs |
|---|---|---|
| `macos-validation.yml` | PR, main | Build the unmodified-behavior **desktop macOS** target from our tree — proves downstream patches don't break upstream targets (NFR-MNT-3) |
| `ios-simulator.yml` | PR, main | CMake configure, arm64 Simulator build, link all deps, launch smoke test (boot Simulator, launch app, assert process alive + first frame logged) where runner minutes permit |
| `ios-device.yml` | PR, main | Unsigned arm64 device build (`CODE_SIGNING_ALLOWED=NO`), verify `.app` bundle structure and required resources present; **no signing credentials in CI** |
| `hygiene.yml` | PR | formatting (upstream style), static analysis, license-header checks, generated-file checks, dependency-license inventory diff, forbidden-asset scan (regex for TTD filenames + content hashes) |
| `upstream-drift.yml` | weekly cron | detect new upstream release; attempt subtree merge + patch apply in a scratch branch; build all targets; open an issue with the result (conflicts or green) |

**BR-11.** CI shall never require private signing credentials; everything CI produces is unsigned.

## 6. Release artifacts

**BR-12.** A tagged release publishes: source archive (the exact tree); the patch set vs. the recorded upstream base (`git format-patch` series); unsigned IPA; the Xcode project/workspace generation inputs; dependency manifest; SHA-256 checksums for every artifact; the **corresponding-source bundle** satisfying GPLv2 for that exact binary; and all license notices. Release automation lives in `.github/workflows/release.yml` and is reproducible from a clean clone.

**BR-13.** Every binary's About screen shows: app version, upstream base tag + commit, and patch-set revision — the triple needed to reconstruct the build.
