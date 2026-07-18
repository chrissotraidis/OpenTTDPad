# 04 — Pointer and Keyboard Specification

Desktop-grade input is a primary goal (PG-4), not an afterthought: a Magic Keyboard iPad must play like a laptop. Upstream's SDL2 driver already understands precise two-axis wheel data, right-click, mouse capture, and keyboard mapping — the work here is mostly *enabling and validating* it on iPadOS, then closing gaps.

---

## 1. Enabling genuine pointer events

**PK-1.** The app shall declare `UIApplicationSupportsIndirectInputEvents = true` so SDL receives genuine mouse/trackpad events instead of touch emulation. Validate on current iPadOS at P0.4.

**PK-2.** Synthetic-event separation (EXP-7): touch shall not generate duplicate mouse events and vice versa. Configure SDL's touch↔mouse synthesis hints (`SDL_HINT_TOUCH_MOUSE_EVENTS=0`, `SDL_HINT_MOUSE_TOUCH_EVENTS=0`; verify exact names/behavior against the SDL version in use) and tag events by source in the input router ([02-architecture.md](02-architecture.md) §5).

## 2. Pointer requirements

| ID | Requirement |
|----|-------------|
| PK-3 | Left-click, right-click, and middle-click (where hardware provides it) map to OpenTTD's native semantics |
| PK-4 | Horizontal and vertical scrolling, including precise trackpad deltas, drive lists and viewport scrolling as on desktop |
| PK-5 | Click-and-drag works for construction, window dragging, scrollbars, and map scrolling per desktop behavior |
| PK-6 | Hover works: tooltips appear on hover with desktop timing; hover states render |
| PK-7 | The cursor is visible, correctly themed, and hidden/shown per OpenTTD's cursor logic; a high-contrast pointer option exists (NFR-ACC-5) |
| PK-8 | Edge scrolling works with a pointer (screen-edge push scrolls the viewport) and is separately toggleable |
| PK-9 | Desktop-style in-game window dragging by title bar works with pointer |
| PK-10 | Trackpad two-finger scroll and click-variants follow iPadOS conventions (secondary click = two-finger click / control-click) |

## 3. Keyboard requirements

| ID | Requirement |
|----|-------------|
| PK-11 | All existing OpenTTD shortcuts function, driven by upstream's hotkey system (`hotkeys.cfg` remains user-configurable) |
| PK-12 | Modifiers: Escape, Control, Shift, Option/Alt work as their desktop equivalents; Command is mapped where useful and never fights system-reserved combos (Cmd-H, Cmd-Tab, Globe) |
| PK-13 | Arrow keys scroll the viewport; function-key equivalents provided where the keyboard has them, with on-screen or remapped fallbacks where it does not (Magic Keyboard has no F-row) |
| PK-14 | Text entry works in every OpenTTD text field via hardware keyboard, including non-ASCII input |
| PK-15 | The software keyboard appears via SDL text input (`SDL_StartTextInput`) whenever a text field focuses and no hardware keyboard is attached, and dismisses on blur (EXP-8) |
| PK-16 | Multiplayer chat and the developer console (where build settings permit the console) are fully operable from hardware keyboard |
| PK-17 | Key bindings are configurable in-app (reusing upstream's hotkey files; a minimal UI or documented file editing is acceptable for 1.0) |

**Reserved-key audit (task P4.1):** enumerate upstream's default hotkeys; for each combination intercepted by iPadOS, define and document a substitute binding shipped in the default `hotkeys.cfg`.

## 4. Input-mode switching

**PK-18.** Switching among touch, mouse, keyboard-plus-touch, and Pencil-plus-keyboard shall be instantaneous — no restart, no settings change, no mode toggle.

**PK-19.** Touch helper indicators (hints, oversized affordances that exist only for fingers) may fade after pointer movement and reappear on the next touch event; gameplay behavior itself never silently changes.

**PK-20.** Device attach/detach (keyboard, mouse, trackpad) mid-game shall be handled gracefully: no crash, no stuck modifier state, no lost cursor ([06-saves-lifecycle.md](06-saves-lifecycle.md) §8).

## 5. Apple Pencil

**PK-21 (Phase 4).** Pencil contact acts as precise primary selection (TI-13): no drag-to-pan on Pencil contact by default (Pencil drags construct when a tool is active, else select). Pencil hover (on supporting hardware) previews the tile/target under the tip. Double-tap/squeeze gestures may map to tool-cancel; configurable, and never the only path (NFR-ACC-7).

## 6. Acceptance evidence

Phase 1 exit requires PK-1…PK-5 basics demonstrated on hardware (EXP-6: left-click, right-click, wheel, hover, drag). Phase 4 exit requires the full table above plus the reserved-key audit, verified against the input matrix in [10-testing.md](10-testing.md) §3.
