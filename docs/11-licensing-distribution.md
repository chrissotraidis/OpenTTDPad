# 11 — Licensing and Distribution

GPLv2 obligations, the base-set license audit, distribution channels in order of adoption, and the conditional App Store path. Compliance is a prime directive; an upstream issue has previously alleged an App Store package using OpenTTD code with ads and without proper source/attribution — that failure mode is the anti-pattern this document exists to prevent.

---

## 1. OpenTTD license obligations

OpenTTD is GPLv2, with several bundled components under compatible or separately documented licenses. For **every distributed modified binary** this project shall provide:

- [ ] Complete corresponding source for that exact binary (tag ↔ artifact mapping, BR-12/BR-13)
- [ ] The GPLv2 license text and all component license texts
- [ ] Clear identification of modifications (published patch series + `PATCHES.md`)
- [ ] Preserved attribution and copyright notices

The application shall **not**: conceal its upstream origin; withhold corresponding source; add proprietary closed engine modifications incompatible with GPL obligations; remove attribution; or present itself as the official upstream release (branding must be distinct and non-misleading — "OpenTTD for iPadOS, an unofficial port of OpenTTD").

## 2. Base-set and third-party licenses

Per CO-3, audit before bundling: OpenGFX, OpenSFX, OpenMSX (each set's *current* license and notice requirements — do not assume uniformity; OpenSFX has historically differed), SDL2, zlib, liblzma, libpng, libcurl, FreeType, HarfBuzz, ICU. Output: `THIRD_PARTY_NOTICES.md` (generated per BR-6) + the in-app notices screen (CO-4). The hygiene CI job diffs the dependency inventory against the notices file on every PR.

## 3. Distribution channels (in adoption order)

| # | Channel | Requirements |
|---|---------|--------------|
| 1 | GitHub source + build-it-yourself (Xcode) | docs from G3; always available |
| 2 | Unsigned IPA releases | BR-12 artifacts + checksums |
| 3 | AltStore / SideStore / Sideloadly documentation | tested sideload guide in README |
| 4 | Limited TestFlight | only after license review (P5.5) |
| 5 | App Store | conditional — §4 |

Channels 1–2 are the *smallest defensible release* and gate 1.0; nothing later may compromise them.

## 4. App Store — conditional, never a 1.0 success criterion

Before any submission, all of:

- [ ] Independent open-source licensing review (GPLv2 vs. current Apple terms; documented conclusion)
- [ ] Corresponding source published for the exact submitted binary
- [ ] Every applicable notice included in-app
- [ ] Policy audit of downloadable NewGRFs / AI / Game Scripts (interpreted content) against current App Review guidelines
- [ ] Non-misleading branding; no ads; no proprietary lock-in; in-app open-source section live
- [ ] Maintainer sign-off recorded in `docs/DEVIATIONS.md`-adjacent decision record

A rejection or dispute never blocks channels 1–3 (R-07).

## 5. Repository licensing

When the engine subtree lands, the root `LICENSE` is GPLv2 (upstream's). The `/docs` PRD suite is project documentation, CC-BY-4.0 unless the maintainer records otherwise ([08-repository-strategy.md](08-repository-strategy.md) §6). Contributions are accepted under the same terms (inbound = outbound); no CLA.
