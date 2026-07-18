# 12 — Risk Register

Live register; review at every gate. Probability/impact reflect the research snapshot — update them as evidence lands.

| ID | Risk | Prob. | Impact | Detection | Mitigation |
|----|------|:-----:|:------:|-----------|------------|
| R-01 | SDL surface path fails on modern iOS | Medium | High | P0.3 first-frame test | Adapt SDL renderer or host loop (ADR-007 Option B) before any UX work; stop-condition report if major systems need replacing |
| R-02 | Touch controls remain confusing (the Android fork's core complaint) | High | High | Structured usability testing (doc 10 §8) each Phase-2 iteration | Direct touch, tool-aware gesture routing, precision mode; tune constants from testing; EXP-10 blocks public release |
| R-03 | Upstream changes break the fork | Medium | High | Weekly `upstream-drift.yml` CI | Patch isolation (BR-24/25), sync within two weeks of stable releases, upstream generic work |
| R-04 | UI scale makes map zoom unusable on high-density displays | High | Medium | Test all device classes at P2.8 | Separate UI/font/hit-area/world-zoom scales (TI-25); per-device presets (TI-26) |
| R-05 | Backgrounding corrupts state | Low-med | High | T-LIFE stress suite | Hard pause + emergency autosave + atomic writes (SL-5…SL-10) |
| R-06 | Multiplayer disconnects frequently on iPad lifecycle | Medium | Medium | T-PERF-6 + network-transition tests | Clear disconnect UX (MP-1…MP-4); defer advanced recovery (MP-7) |
| R-07 | Downloadable content creates App Store issues | Medium | High | Policy/legal review before submission | App Store is conditional (doc 11 §4); channels 1–3 unaffected |
| R-08 | GPL compliance incomplete | Low-med | High | Automated notice/source audit in CI (hygiene job) | Publish exact corresponding source per release (BR-12); compliance checklist in doc 11 |
| R-09 | Bundled base-set license mishandled | Low-med | High | License inventory + CO-3 audit | Include all notices or switch that set to on-demand download |
| R-10 | iCloud conflicts overwrite saves | Medium | High | Conflict simulation before enabling | Deferred post-1.0 until conflict design approved (SL-12) |
| R-11 | Android interaction code copied incompatibly | Low | Medium | Code review + `PATCHES.md` provenance | Reimplement concepts against current upstream (prime directive 6) |
| R-12 | Project produces little public excitement | Medium | Low | Community alpha metrics (doc 13) | Keep initial scope controlled; ship the smallest defensible release; position honestly |

**Escalation:** any risk observed at High/High moves to the top of the next gate review with a written option analysis (`docs/reports/`).
