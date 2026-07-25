# 03 — Touch Interaction Specification

The complete touch behavior contract. This is the highest-product-risk area of the project (R-02): the Android fork's reviews prove that a *running* OpenTTD with poor controls is not a good product. Every requirement here is testable; the tunable constants in §6 are the single source of truth for gesture thresholds.

---

## 1. Design principle

**TI-1.** The screen shall not behave primarily like a laptop trackpad. Players interact with the object or location *under their finger* (direct manipulation). A precision pointer mode exists for the cases where direct touch becomes ambiguous.

**TI-2.** Every gesture-only action shall also be reachable through a button, menu, or keyboard path (NFR-ACC-7).

## 2. Default gesture catalog

| ID | Gesture | Default behavior |
|----|---------|------------------|
| TI-3 | Tap map object | Select or activate the object |
| TI-4 | Tap empty map tile | Set tool target or inspect tile |
| TI-5 | One-finger move on empty map (no construction tool active) | Move the visible touch cursor with the finger without panning; lift to tap, or hold for precision |
| TI-6 | Pinch | Zoom map (continuous feel; §5.4) |
| TI-7 | Two-finger drag | **Always** pan map, regardless of active tool |
| TI-8 | Two-finger tap | Secondary click (right-click semantics) |
| TI-9 | Long press | Open contextual/precision interaction (§4) |
| TI-10 | Tap UI button | Activate button |
| TI-11 | Drag scrollbar | Scroll directly (thumb follows finger) |
| TI-12 | Double tap vehicle or station | Open the appropriate detail window |
| TI-13 | Apple Pencil tap | Precise direct selection (Pencil never pans on contact; hover where hardware supports it may preview) |
| TI-14 | Hardware right-click | Native OpenTTD secondary-click behavior (PK-3) |

## 3. Construction interaction

Construction tools create the largest gesture conflict: a one-finger drag may plausibly mean pan, lay track/road, select an area, terraform, or place multiple objects.

**Binding rules:**

- **TI-15.** When no construction tool is active, one-finger movement does not pan. This preserves one finger for direct interaction and precision; use two fingers to move the map.
- **TI-16.** When a line-construction tool is active (rail, road, canal, etc.), one-finger dragging constructs.
- **TI-17.** Two-finger dragging always pans (escape hatch, consistent with TI-7).
- **TI-18.** A visible tool-state indicator shall make the active drag behavior obvious at a glance (e.g. active-tool highlight plus a small "drag builds / drag pans" glyph near the toolbar).
- **TI-19.** A Cancel/abort control shall remain easily reachable whenever a tool is active (minimum 44 pt target, thumb-reachable in landscape).
- **TI-19a.** Construction shall not begin until the drag passes the deliberate-movement threshold `DRAG_ACTIVATE_PT` (§6) — an accidental micro-drag while tapping must not lay track.
- **TI-19b.** During a construction drag, live preview (upstream's existing highlight) shall track the finger; lifting commits, and dragging onto the Cancel control (or two-finger tap) aborts without committing.

## 4. Precision mode

**TI-20.** Long-press (`LONG_PRESS_MS`) on the map shall enter precision mode: a magnified loupe (`PRECISION_MAG`×) showing the area under the finger with a crosshair cursor offset above the fingertip.

**TI-21.** While in precision mode, moving the finger moves the crosshair 1:1 in *screen* space (magnified world space), and the crosshair snaps to relevant tile boundaries/track pieces where the active tool has snappable targets.

**TI-22.** Lifting the finger in precision mode performs the primary action at the crosshair; an on-loupe cancel affordance (or two-finger tap) exits without acting.

**TI-23.** Precision mode is the designated path for: signals, waypoints, small toolbar controls, bridge endpoints, tunnel entrances, overlapping station tiles, dense urban construction, exact terrain corners.

**TI-24.** Long-press over a UI window (not the map) shall instead show the contextual interaction for that widget where one exists (e.g. tooltip text on a button, matching desktop hover), else do nothing.

## 5. Gesture state machine

Implemented in `src/touch/gesture_state.cpp` ([02-architecture.md](02-architecture.md) §2.3). States:

```text
IDLE
 ├─ finger 1 down ────────────────► PENDING (start pos, start time recorded)
 ├─ finger 2 down while PENDING ──► TWO_FINGER_PENDING
PENDING
 ├─ movement > DRAG_ACTIVATE_PT & no line tool ──► ONE_FINGER_SUPPRESSED
 ├─ movement > DRAG_ACTIVATE_PT & line tool ─────► CONSTRUCTING
 ├─ hold > LONG_PRESS_MS, movement < TAP_SLOP_PT ─► PRECISION
 ├─ up within TAP_MAX_MS, movement < TAP_SLOP_PT ─► emit TAP → IDLE
TWO_FINGER_PENDING
 ├─ both up within TWO_TAP_MAX_MS, low movement ──► emit SECONDARY_CLICK → IDLE
 ├─ inter-finger distance delta > PINCH_ACTIVATE_PT ─► PINCHING
 ├─ centroid movement > DRAG_ACTIVATE_PT ─────────► PANNING (two-finger)
ONE_FINGER_SUPPRESSED ── movement does nothing; finger up → IDLE; second finger down → TWO_FINGER_PENDING
PANNING      ── stays a pan until either finger lifts; lift ends movement and suppresses the remaining finger
CONSTRUCTING ── finger up commits → IDLE; second finger down → abort construct, → TWO_FINGER_PENDING
PINCHING     ── stays a pinch until either finger lifts; lift ends the gesture and suppresses the remaining finger
PRECISION    ── finger up → act → IDLE; cancel → IDLE
```

Notes:

- **5.1 Double-tap detection (TI-12)** wraps TAP emission: a second TAP within `DOUBLE_TAP_MS` and `DOUBLE_TAP_SLOP_PT` of the first becomes DOUBLE_TAP; otherwise the first TAP is delivered after the window closes *only* for double-tap-sensitive targets — plain buttons fire immediately (no perceived lag on common taps).
- **5.2 Palm/edge rejection:** fingers landing in the outermost `EDGE_REJECT_PT` band participate only in system gestures; ignore for game input.
- **5.3 Momentum:** viewport panning gets standard deceleration (flick momentum) matching platform feel; construction drags never have momentum.
- **5.4 Pinch zoom (TI-6):** SDL reports the two contacts separately, so the recognizer uses a short intent window before choosing pan or pinch. Once chosen, the gesture stays in that mode until lift: parallel motion cannot accidentally zoom, while deliberate spacing changes emit every crossed discrete zoom step around the finger midpoint.
- **5.5 Finger-count transitions:** when a two-finger pan or pinch drops to one finger, the recognizer ends map movement immediately and suppresses the remaining contact until lift. This prevents a discontinuous viewport jump and preserves the rule that map movement always requires two fingers.

## 6. Tunable constants (single source of truth)

Defined in `src/touch/touch_settings.hpp`; defaults below, all in points (pt) and milliseconds.

| Constant | Default | Range | Meaning |
|----------|--------:|-------|---------|
| `TAP_SLOP_PT` | 8 | 4–16 | Max movement for a tap |
| `TAP_MAX_MS` | 300 | 150–500 | Max duration for a tap |
| `DOUBLE_TAP_MS` | 250 | 150–400 | Second-tap window |
| `DOUBLE_TAP_SLOP_PT` | 24 | — | Max distance between the two taps |
| `LONG_PRESS_MS` | 500 | 300–800 (user setting, NFR-ACC-6) | Precision-mode entry |
| `DRAG_ACTIVATE_PT` | 10 | 6–20 | Deliberate-drag threshold (TI-19a) |
| `TWO_TAP_MAX_MS` | 250 | — | Two-finger-tap max duration |
| `TWO_TAP_STAGGER_MS` | 100 | — | Max delay between the two finger-downs |
| `PINCH_ACTIVATE_PT` | 24 | — | Inter-finger distance change to enter PINCHING |
| `PINCH_STEP_FACTOR` | 1.25 | — | Scale ratio per discrete zoom step |
| `PRECISION_MAG` | 2.0× | 1.5–3.0 | Loupe magnification |
| `PRECISION_OFFSET_PT` | 60 | — | Crosshair offset above fingertip |
| `EDGE_REJECT_PT` | 8 | — | Edge band ignored for game input |
| `MIN_TARGET_PT` | 44 | — | Minimum effective touch target (Apple guidance) |

These defaults are starting values; Phase 2 usability testing (EXP-10) tunes them, and tuned values are committed back into this table.

## 7. UI scaling

**TI-25.** The application shall expose **separate** controls for: interface scale, viewport zoom, font size, and touch-target enlargement. These are never collapsed into one global scale — an upstream issue documents that large GUI scaling can eat the available world zoom range, which is especially bad on high-density tablets (R-04).

**TI-26.** Required per-device initial defaults:

| Device class | Initial UI scale |
|--------------|------------------|
| iPad mini | Large |
| Standard iPad | Medium-large |
| 11-inch iPad Air / Pro | Medium |
| 13-inch iPad Air / Pro | Medium |
| External display (later) | Automatic from effective resolution |

Concrete numeric scale values are chosen at task P2.8 by on-device evaluation and recorded here.

**TI-27 (expanded hit testing).** Interactive targets shall have an effective touch area of at least `MIN_TARGET_PT` square. Small desktop widgets keep their visuals; their *hit regions* are enlarged for touch input only (never for pointer input). Overlapping expanded regions resolve to the nearest-center widget.

**TI-28 (safe areas).** No interactive element under the rounded corners, camera housing, or home-indicator region; main toolbar and status bar are inset accordingly.

## 8. Touch-specific settings (persisted, FR-11)

| Setting | Default |
|---------|---------|
| Direct touch enabled | on |
| Long-press duration | 500 ms |
| Two-finger secondary click | on |
| Precision magnifier | on |
| Touch-target expansion | on |
| Map-pan sensitivity | 1.0× |
| Pinch sensitivity | 1.0× |
| Edge scrolling (touch) | off (pointer edge-scroll is separate, PK-8) |
| Haptics | on (light impact on construction commit, selection change) |
| Left-handed toolbar preference | off |
| Auto-hide touch hints when pointer connected | on |

The native Touch Controls form exposes gesture response, long-press duration,
touch-target expansion, map glide, left/right control placement, haptics, and
touch-tip reset in one screen. Left/right placement moves both the compact
lower-corner options control and the active construction Cancel affordance; the
nearby tool hint is clamped inside the safe area. The form has an explicit Done
action.

## 9. Touch onboarding hints

First-run contextual hints (dismissable, never modal mid-game): one-time overlay explaining direct taps, one-finger construction, two-finger map movement, pinch, and precision on first map view; first-tool-activation hint explaining TI-16/TI-17; precision-mode discovery hint the first time a small-target tap misses twice in succession. The first map hint also dismisses itself after ten seconds so it cannot remain over gameplay. Hints are suppressed permanently once dismissed, and all are suppressed when a pointer is the active input (per auto-hide setting).
