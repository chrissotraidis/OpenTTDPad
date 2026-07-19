# Requirement deviations

Deliberate deviations from a PRD **shall** requirement require maintainer
approval and a row here. Re-verified upstream facts that supersede stale PRD
numbers belong in `UPSTREAM_FACTS.md`, not here.

| Requirement | Alternative | Reason | Approved by / date |
|---|---|---|---|
| Builder §2 / roadmap G0 order | Continue Simulator-only dependency, touch, and UX engineering while physical-device experiments remain open; never claim G0 passed | The maintainer explicitly requested an end-to-end Simulator build and exhaustive macOS testing, but no physical iPad is connected. Waiting would prevent safe Simulator-verifiable work without making hardware evidence more available. | Maintainer request, 2026-07-18 |
