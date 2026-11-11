# Monochrome UI/UX Refresh

## Goal

Give WORLDBREAK a cohesive in-game interface inspired by the clarity, layered surfaces, and readable hierarchy of modern action-RPG interfaces such as Genshin Impact, while keeping the visual identity original and using no copied proprietary assets or layouts.

## Visual direction

- **Palette:** near-black panel surfaces, white primary text and outlines, neutral gray secondary text and dividers.
- **Panels:** consistent rounded corners, thin visible borders, restrained translucent fills, and predictable internal padding.
- **Controls:** shared normal, hover, pressed, focus, and disabled states for buttons and selectors.
- **Hierarchy:** clear product title, section labels, grouped settings, aligned values, and readable status feedback.
- **Density:** generous enough spacing to scan quickly, while preserving the existing 1280x720 baseline.

## Scope

### HUD
- Restyle the WORLDBREAK status card with a clear title/status hierarchy.
- Replace the loose bottom hint line with a compact, bordered control/keycap strip.
- Keep the first-person crosshair simple and legible.

### Simulation Control
- Restyle world/scenario/material/camera selectors.
- Restyle impact, gravity, and time-scale controls with aligned values and consistent button sizing.
- Establish a clear primary action for settled scenario runs; keep pause/reset/export as secondary actions.
- Put the panel content in a vertical scroll container so controls remain reachable on shorter windows.

### Spawn Menu
- Apply the same panel, border, radius, typography, and button states.
- Separate the item grid from spawn feedback and capacity information.

### Debug Overlay
- Apply the same monochrome surface and typography treatment without changing diagnostic content.

## Design tokens (initial target)

| Token | Target |
|---|---|
| Primary surface | Near-black, slightly translucent |
| Secondary surface | Charcoal / dark neutral |
| Primary text | Soft white |
| Secondary text | Medium neutral gray |
| Border | Visible light-gray / white at low opacity |
| Accent | White, used sparingly |
| Panel radius | 12-16 px |
| Control radius | 7-9 px |
| Panel border | 1 px |
| Control border | 1 px |

## Acceptance criteria

- HUD, Simulation Control, Spawn Menu, and Debug Overlay share one reusable monochrome theme.
- Panels have rounded corners and visible borders.
- Buttons and selectors have distinct normal, hover, pressed, focus, and disabled states.
- Status text, labels, values, and actions have a consistent visual hierarchy.
- Simulation Control remains usable when the window is shorter than the full panel content.
- Existing simulation, world-loading, sandbox, and input behavior remains unchanged.
- Headless UI regression verifies the theme's palette, panel radius/border, and interactive control styles.
- Godot 4.7.2 Linux and Windows validation passes.

## Implementation checklist

- [x] Establish monochrome design tokens and reusable Theme styles.
- [x] Refresh HUD and control-hint strip.
- [x] Refresh Simulation Control and make it scrollable.
- [x] Refresh Spawn Menu and status/capacity feedback.
- [x] Refresh Debug Overlay.
- [x] Add UI theme regression assertions.
- [x] Update README/project status/work log.
- [x] Pass Linux and Windows CI ([run #43041887242](https://github.com/PanDuroDev/Idk/actions/runs/43041887242)).
- [ ] Manually review the layout at 1280x720 and a shorter window height; confirm no overlap, clipping, or unreadable key hints.

## Scope boundaries

This is a UI/UX pass only. Do not change physics, simulation mechanics, world configuration formats, asset licensing, or gameplay input bindings.
