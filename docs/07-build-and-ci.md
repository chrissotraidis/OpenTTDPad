# 07 — Build System and Continuous Integration

The reproducible-build contract: toolchain, the two-stage cross-compile, dependency strategy, developer scripts, and CI workflows. "Repeatable Xcode and command-line build" is primary goal PG-8.

---

## 1. Baseline facts (verify at P0.0)

OpenTTD 15.3 requires CMake 3.17 and a C++20 compiler; the generic flow is
`cmake .. && cmake --build .`. Optional/encouraged dependencies include zlib,
liblzma, libpng, libcurl, SDL2, FreeType, HarfBuzz, and ICU. The pinned iPad
pipeline has each release-relevant dependency enabled; see
`THIRD_PARTY_NOTICES.md` and `UPSTREAM_FACTS.md` for exact versions.

## 2. The cross-compilation shape

**BR-1.** OpenTTD's build runs generated host tools (string/settings generators) *during* the build. Cross-compiling therefore uses a **two-stage build**, the same pattern upstream's emscripten target uses:

```sh
# Stage 1 — native macOS host tools
cmake -S engine -B build/host-tools -G Ninja -DOPTION_TOOLS_ONLY=ON
cmake --build build/host-tools --target tools

# Stage 2 — the checked-in scripts build every static dependency for the chosen
# SDK, then configure OpenTTD with HOST_BINARY_DIR=build/host-tools.
./scripts/build-simulator.sh   # iphonesimulator, arm64, iPadOS 17+
./scripts/build-device.sh      # iphoneos, arm64, unsigned
```

The exact option/variable names for the host-tool handoff must be read from upstream's `cmake/` and emscripten config at P0.2 and recorded in `UPSTREAM_FACTS.md` — do not guess them.

**BR-2.** The build scripts pass platform/SDK selection, arm64-only, iPadOS
17.0 minimum, and cross-root dependency paths directly to CMake. The device
bundle remains unsigned, and host generators enter only through
`HOST_BINARY_DIR`.

**BR-3.** Build targets: iOS Simulator arm64; physical iPad arm64; Debug / RelWithDebInfo / Release configurations; unsigned device archive; unsigned IPA packaging where technically appropriate.

## 3. Dependency strategy

**BR-4.** All third-party libraries are **static** for iOS (no dylib bundling
complexity). P0.2 selected scripted source builds pinned by tag and checksum.

The scripts build SDL, xz/liblzma, libpng, curl/Mbed TLS, FreeType, and HarfBuzz.
They use SDK zlib and the SDK ICU library with matching pinned ICU headers.

**BR-5.** Dependency tiers for iOS:

| Dependency | Tier | Note |
|---|---|---|
| SDL2 | required | official iOS support; version pinned; build static |
| zlib | required | may use the SDK's zlib |
| liblzma | required | modern desktop saves use it — required for FR-7 |
| libpng | required | heightmaps, screenshots |
| libcurl + Mbed TLS | enabled | static HTTPS stack using the packaged, dated Mozilla CA extract; peer verification remains on |
| FreeType + HarfBuzz + ICU | enabled | static FreeType/HarfBuzz plus SDK `libicucore` paired with pinned ICU 78.1 headers; CoreText chooses language-capable system fallback fonts |

**BR-6.** The checked-in dependency inventory records name, version, source,
role, and license in `THIRD_PARTY_NOTICES.md`. `scripts/verify-release.sh`
cross-checks every required component and packaged bundle resource.

## 4. Developer experience

**BR-7.** The documented setup shall be exactly:

```bash
git clone <repository>
cd OpenTTDPad
./scripts/bootstrap-ios.sh
./scripts/run-simulator.sh
```

For hardware, run `./scripts/build-device.sh`, then sign the generated app with
the maintainer's own Apple identity/profile. CI and this repository carry no
signing secrets.

**BR-8.** `scripts/bootstrap-ios.sh` shall: verify Xcode + CMake presence and versions; initialize/fetch dependencies (per BR-4 option); fetch or verify pinned SDL2; fetch free base content into the packaging tree (with license audit stamp, CO-3); run both build stages to generate the Xcode project; print signing instructions; and **never modify global system configuration**.

**BR-9.** Script set:

| Script | Responsibility |
|---|---|
| `scripts/bootstrap-ios.sh` | BR-8 |
| `scripts/build-simulator.sh` | clean CLI Simulator build + boot smoke test where possible |
| `scripts/build-device.sh` | clean CLI unsigned device build (`CODE_SIGNING_ALLOWED=NO`) |
| `scripts/compile-app-assets.sh` | compile/merge the native iPad icon asset catalog during packaging |
| `scripts/package-ipa.sh` | unsigned IPA from the device archive, plus checksums |
| `scripts/package-source-release.sh` | exact tracked tree, dependency sources, free input archives, downstream patch series, and checksums |
| `scripts/sync-upstream.sh` | upstream subtree pull + patch reapply ([08-repository-strategy.md](08-repository-strategy.md) §5) |

All scripts are idempotent and fail loudly with actionable messages.

## 5. Continuous integration (GitHub Actions, macOS runners)

> **Current setup.** Hygiene runs on Linux for every change. The macOS
> workflows (macOS validation, iPad Simulator, unsigned iPad device) run on
> every push and pull request when the repository is public, and only on
> demand while it is private. `scripts/check-local.sh` runs the same checks on
> a developer Mac.

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
