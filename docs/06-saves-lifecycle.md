# 06 — Saves, Sandbox, and Application Lifecycle

Where data lives, how saves are protected, exactly what happens on every lifecycle transition, and the multiplayer lifecycle rules.

---

## 1. Save compatibility contract

**SL-1.** Saves are upstream-format, unmodified (no new save format, no iPad-only chunks). Upstream guarantees newer OpenTTD loads older valid saves; this port inherits and must not break that: an iPad save loads on desktop OpenTTD of the same or newer version, and vice versa (FR-7, NFR-REL-5).

## 2. Sandbox layout

**SL-2.** Directory mapping (implemented in `src/os/ios/ios_paths.cpp`):

| OpenTTD concept | iOS location | Rationale |
|---|---|---|
| Personal dir (saves, scenarios, screenshots, config, content) | `Documents/` | User-visible in Files (CO-16); survives updates; simple mental model |
| `save/`, `save/autosave/` | `Documents/save/` | matches desktop layout |
| `scenario/`, `screenshot/`, `baseset/`, `newgrf/`, `content_download/` | `Documents/<same>` | same |
| `openttd.cfg`, `hotkeys.cfg` | `Documents/` | user-inspectable, exportable |
| Cache dir (sprite cache etc.) | `Library/Caches/OpenTTD/` | purgeable by the OS; never user data |
| Crash logs / diagnostics | `Library/Application Support/OpenTTD/crash/` | not cluttering Documents; exported on request |

**SL-3.** Nothing outside the sandbox is ever written; nothing in `Library/Caches` is ever the only copy of user data.

**SL-4.** Saves shall survive app updates (Documents does by platform contract — verified by T-LIFE-10 anyway). The app shall warn users, in onboarding and in settings, that **deleting the app deletes local saves**, and shall expose an explicit **"Export All Saves"** command (zip of `save/` via share sheet).

**SL-5.** Atomic writes (NFR-REL-1): saves and config write to a temp file in the same directory, fsync, then rename. A crash at any moment leaves either the old or the new file, never a truncated hybrid.

## 3. Lifecycle transitions

Implemented by `ios_lifecycle.cpp` + `SceneDelegate` ([02-architecture.md](02-architecture.md) §2).

**SL-6. On scene resign-active (control center pull, app switcher, alerts):**
1. Pause single-player simulation (hard pause, not just render stop)
2. Persist configuration
3. Reduce audio (duck or pause music; stop new effects)

**SL-7. On did-enter-background:**
1. Complete/flush any in-flight save; then create a lightweight **emergency autosave** (`autosave/emergency.sav`, rotating 2 copies) inside a `beginBackgroundTask` grant so iOS allows it to finish
2. Stop or suspend audio entirely
3. Release regenerable resources (sprite-cache trim) under memory pressure
4. Stop the game loop completely (a suspended process must not hold a half-rendered frame — see [02-architecture.md](02-architecture.md) §3)

**SL-8. On will-enter-foreground / did-become-active:**
1. Reactivate audio session; verify route
2. Validate renderer and surface; recreate if invalidated
3. Restore input state (clear stuck modifiers/gestures)
4. Remain **paused until the user resumes**, unless the interruption was momentary (< `RESUME_GRACE_MS`, default 3000 ms — then auto-resume)

**SL-9. On termination / memory-kill while backgrounded:** the emergency autosave from SL-7 is the recovery point; next launch offers "Continue from where you left off?" if the emergency autosave is newer than the last manual save.

**SL-10. Memory warnings:** trim caches, drop undo-able transient buffers; never drop unsaved game state without first attempting the emergency autosave path.

**SL-11. Audio interruptions** (calls, Siri, other apps): pause on interruption-began; on interruption-ended with resume hint, restore session and continue per SL-8 rule 4; route changes (AirPods removed, etc.) never crash and follow the platform convention of pausing on route *loss*.

## 4. iCloud synchronization — deferred (post-1.0)

**SL-12.** When implemented: opt-in and off by default; local play never requires network; conflicts never silently overwrite newer saves — both copies kept and surfaced ("conflicted copy" naming); multiplayer autosaves distinguishable; files remain desktop-compatible (SL-1). Do not start this before a robust conflict design exists (R-10). No iCloud entitlement ships in 1.0.

## 5. Crash and diagnostics

**SL-13.** Wire OpenTTD's crash-log machinery to the sandbox crash directory; on next launch after a crash, offer (never auto-send, NFR-PRV-4) export of the crash bundle via share sheet. The bundle includes: OpenTTD version + base commit, device model, OS version, loaded NewGRFs, and the crash log.

## 6. Device changes (PK-20)

**SL-14.** Handle without crash or state loss: keyboard attach/detach; mouse/trackpad attach/detach; audio-route changes; rotation notifications (landscape↔landscape flip must be seamless; portrait is refused by the orientation mask); Stage Manager resize events (Phase 4 — until then `UIRequiresFullScreen` avoids them); external-monitor connect (Phase 4); memory warnings (SL-10).

## 7. Multiplayer lifecycle (Phase 5)

Backgrounding cannot behave like single-player pause: the server keeps running.

| ID | Requirement |
|----|-------------|
| MP-1 | Entering background during multiplayer shows a clear pre-warning the first time ("iPadOS will disconnect you after a short time in the background") |
| MP-2 | The connection is kept alive only for the limited background window the OS grants; no illegitimate background-execution tricks |
| MP-3 | Disconnection is graceful: server notified when possible; client state cleanly torn down |
| MP-4 | On return, the user gets an explicit result: reconnect offer or return-to-menu with reason — never a frozen dead session |
| MP-5 | The active local save/autosave state is never corrupted by a disconnect at any moment (NFR-REL-1) |
| MP-6 | Multiplayer autosaves are labeled distinctly from single-player autosaves |
| MP-7 | Deferred (post-1.0): background reconnection, push notifications, persistent iPad-hosted servers, deep-link joining, Game Center |
