# 05 — Content and Onboarding

How the app becomes playable on first launch with zero user-supplied files, how optional original Transport Tycoon Deluxe assets are imported, how online content works, and the Files-app integration contract.

---

## 1. Base content strategy

**CO-1.** Version 1 shall provide a complete freely playable configuration: users never need to own Transport Tycoon Deluxe. The free base sets are OpenGFX (graphics), OpenSFX (sound), OpenMSX (music).

**CO-2.** Preferred packaging: bundle compatible free **graphics** and **sounds** in the app bundle; **music** is an optional in-app download if its size is material. The user shall never see a missing-assets error on first launch (FR-8).

**CO-3 (license audit — blocking for P1.5).** Before bundling any base set, audit its *current* license and required notices and record the audit in `docs/UPSTREAM_FACTS.md`. Note in particular that OpenSFX has historically carried a different (non-GPL) license than OpenGFX/OpenMSX; whatever the current terms are, the bundle must satisfy them, and all notices must be exposed in-app (CO-4). If a set's license blocks bundling, fall back to first-launch download for that set with a clear progress UI.

**CO-4.** An in-app "Licenses & Credits" screen shall display: OpenTTD's GPLv2 + copyright, each bundled base set's license and credits, SDL and other third-party notices, and a link to this project's corresponding source ([11-licensing-distribution.md](11-licensing-distribution.md)).

## 2. First-launch flow

**CO-5.** The first-launch sequence (native shell UI, before SDL takes over):

```text
1. Launch
2. Welcome + license/attribution summary (link to full notices)
3. Base content check:
     bundled sets present → confirm silently
     any set needs download → show size, progress, retry-on-failure
4. Optional music download offer (skippable, available later in settings)
5. Apply iPad-appropriate interface preset for the detected device class (TI-26)
6. Offer: [Start tutorial hints] [New game] [Import existing saves/content]
7. Hand off to the engine main menu
```

**CO-6.** Every step is resumable: killing the app mid-onboarding resumes at the incomplete step. Declining optional steps is remembered.

**CO-7.** "Import existing saves/content" opens the document picker flow (§6) so a migrating desktop player reaches their save before ever seeing the main menu (US-1).

## 3. Original Transport Tycoon Deluxe importer (secondary goal; target Phase 3, may slip post-1.0)

**CO-8.** An optional importer titled "Import Original Transport Tycoon Deluxe Data" shall let users who legally own TTD bring in their files via the document picker (folder or multi-file selection).

**CO-9.** The importer shall validate the documented original files against OpenTTD's expected base-set metadata (checksums as upstream defines them), accepting either edition:

- Windows edition: `TRG1R.GRF`, `TRGCR.GRF`, `TRGHR.GRF`, `TRGIR.GRF`, `TRGTR.GRF`, `SAMPLE.CAT`
- DOS edition: `TRG1.GRF`, `TRGC.GRF`, `TRGH.GRF`, `TRGI.GRF`, `TRGT.GRF`, `SAMPLE.CAT`
- Optional music: the corresponding GM files

Verify the exact expected-file list and checksums against current upstream documentation at implementation time.

**CO-10.** Valid files are copied into the app's `baseset/` directory; invalid/incomplete selections produce a per-file explanation, never a partial silent install.

**CO-11.** Original assets shall never be committed to the repository, embedded in binaries, downloaded by the app, or included in CI artifacts (prime directive 2).

## 4. Online content (FR-9)

**CO-12.** The in-game content-download system (BaNaNaS) shall work for: NewGRFs, scenarios, heightmaps, AI packages, Game Scripts, and base sets. Downloads are stored under the app's writable content directory ([06-saves-lifecycle.md](06-saves-lifecycle.md) §2) and persist across relaunches.

**CO-13.** Failure handling per NFR-REL-3: interrupted downloads are resumable or cleanly restartable; storage-full produces a clear message. Note for distribution: downloadable scripts/interpreted content needs a separate App Store policy review — this shapes the App Store decision ([11-licensing-distribution.md](11-licensing-distribution.md) §4), not the sideload/source releases.

## 5. Screenshots

**CO-14a.** OpenTTD's screenshot function shall write to the sandbox screenshots directory and offer a share-sheet export; giant-screenshot variants must respect memory limits (fail gracefully, never OOM-crash).

## 6. Files-app integration (FR-7)

**CO-14.** Document types: declare/export UTIs so `.sav` and `.scn` open-with lands in the app; conform heightmap image types to the system image UTIs for import.

**Imports (document picker + open-in):** `.sav` saves · `.scn` scenarios · compatible heightmaps (PNG per upstream support) · NewGRF packages (`.grf`, downloaded-content bundles) · base-set packages · original TTD assets (via CO-8 flow) · `openttd.cfg` where safe (imported config is sanity-filtered: paths and platform-inapplicable keys dropped).

**Exports (share sheet / picker):** saves · scenarios · screenshots · crash reports · configuration diagnostics (a text bundle of settings + version + device info, no personal data beyond what the user can read).

**CO-15.** Import uses security-scoped resources correctly: files are *copied* into the sandbox (no dangling bookmarks needed for 1.0); a copy-progress UI covers large files.

**CO-16.** With `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`, the user's saves are directly visible in the Files app under On My iPad → OpenTTD; the on-disk layout in that tree is exactly upstream's (`save/`, `scenario/`, `screenshot/`) so what users see matches desktop knowledge.
