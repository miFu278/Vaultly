---
version: alpha
name: Vaultly
description: Minimalist monochrome design language for the Vaultly secure photo vault (Flutter web + Android).
colors:
  background: "#F9FAFB"
  surface: "#FFFFFF"
  surface-muted: "#F3F4F6"
  media-canvas: "#F3F4F6"
  border: "#E5E7EB"
  foreground: "#111827"
  foreground-muted: "#6B7280"
  primary: "#111827"
  danger: "#FF5252"
  scrim: "#000000"
typography:
  brand:
    fontSize: 17px
    fontWeight: 700
    letterSpacing: -0.4px
  title-lg:
    fontSize: 26px
    fontWeight: 700
    letterSpacing: -0.5px
  title:
    fontSize: 18px
    fontWeight: 600
    letterSpacing: -0.2px
  heading:
    fontSize: 14px
    fontWeight: 600
    letterSpacing: -0.2px
  body:
    fontSize: 13px
    fontWeight: 500
  label:
    fontSize: 12px
    fontWeight: 500
  caption:
    fontSize: 11px
    fontWeight: 500
  micro:
    fontSize: 10px
    fontWeight: 500
rounded:
  xs: 6px
  sm: 8px
  md: 10px
  lg: 12px
  xl: 16px
spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  pane-breakpoint: 680px
  sidebar-collapsed: 68px
  sidebar-expanded: 250px
  form-max: 440px
  dialog-max: 800px
components:
  photo-tile:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.sm}"
  folder-item:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.md}"
  segmented-control:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.sm}"
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
  media-viewer:
    backgroundColor: "{colors.media-canvas}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.xl}"
---

## Overview

Vaultly is a cross-platform secure photo vault: folders of encrypted images, opened with an account and a 6-digit PIN. The interface is deliberately plain — a neutral gray scale, flat surfaces, hairline borders, and no decoration that competes with the photos. Chrome stays quiet so the media is the only saturated content on screen.

## Colors

The palette is monochrome by design; there is no chromatic brand color.

- **Background (#F9FAFB):** App canvas behind panes and lists.
- **Surface (#FFFFFF):** Bars, dialogs, and elevated panels that sit above the canvas.
- **Surface muted (#F3F4F6):** Selected rows, tiles, chips, and grouped controls — the only way a surface indicates state.
- **Border (#E5E7EB):** 1px hairline that carries all structure and separation.
- **Foreground (#111827):** Primary text, icons, and the interactive ink itself.
- **Foreground muted (#6B7280):** Secondary text, metadata, inactive icons, and placeholders.
- **Primary (#111827):** Identical to foreground. Selection, focus, and active states are expressed as ink, never as a hue.
- **Danger (#FF5252):** Validation and failure text only.
- **Scrim (#000000):** Only behind fullscreen media.

States are alpha steps of `{colors.foreground}` and `{colors.foreground-muted}`, not new colors. `{colors.danger}` is the single exception to the monochrome rule and appears only on the failing control.

## Themes

Light is the default theme; dark reuses every token name with the values below. Theme switching must change values only — never introduce separate `-light`/`-dark` token names or a second palette.

| Token | Light (default) | Dark |
|---|---|---|
| `colors.background` | `#F9FAFB` | `#0F0F11` |
| `colors.surface` | `#FFFFFF` | `#18181B` |
| `colors.surface-muted` | `#F3F4F6` | `#27272A` |
| `colors.media-canvas` | `#F3F4F6` | `#101012` |
| `colors.border` | `#E5E7EB` | `#27272A` |
| `colors.foreground` | `#111827` | `#F4F4F5` |
| `colors.foreground-muted` | `#6B7280` | `#A1A1AA` |
| `colors.primary` | `#111827` | `#F4F4F5` |
| `colors.danger` | `#FF5252` | `#FF5252` |
| `colors.scrim` | `#000000` | `#000000` |

## Typography

One system font family, differentiated by size and weight alone.

- **Brand and titles:** use `brand`, `title`, and `title-lg` with negative tracking. Tighten tracking only on these; leave body and label text untouched.
- **Body and labels:** `body` for row text and list items, `label` for metadata rows, `caption` and `micro` for counts, badges, and tile overlays.
- **Weights:** 700 only for the brand mark and the auth hero, 600 for section and folder titles, 500 for everything else. Never exceed three weights in one view.
- **Numbers:** counts, file sizes, and dates use tabular figures so they do not shift between rows.
- **Density:** every title truncates to a single line with an ellipsis; never wrap a title to a second line to fit a control.

## Layout

An 8px rhythm with 4px (`{spacing.xs}`) and 2px (`{spacing.xxs}`) half-steps for icon and segment gaps.

- **Two-pane:** at or above `{spacing.pane-breakpoint}` show the folder sidebar beside the photo grid, sidebar at `{spacing.sidebar-expanded}` and `{spacing.sidebar-collapsed}` when collapsed.
- **One-pane:** below `{spacing.pane-breakpoint}` move the sidebar into a drawer and keep the grid full width.
- **Left-anchored chrome:** the app bar and pane headers align left; the app bar is a single row of controls, never a second toolbar.
- **Constrained content:** centered forms cap at `{spacing.form-max}`; dialogs cap at `{spacing.dialog-max}`.
- **Grid:** square tiles in 2 to 4 columns with `{spacing.sm}` gutters and `{spacing.md}` page padding; the column count is the only density control.
- **Insets:** every fixed bar respects the device safe area; full-height layouts are sized from the available viewport, never from a fixed screen height.

## Elevation & Depth

Depth is flat. All surfaces sit at elevation zero and hierarchy comes from `{colors.border}` hairlines plus the `{colors.surface}` / `{colors.surface-muted}` shift.

Shadows are transient affordances only: they may appear on pointer hover and on the active segment of a control, and must be gone at rest. Never blur or tint a surface to signal importance, and never animate a blurred or backdrop-filtered surface.

## Shapes

Radii are small and consistent, and scale with the size of the container.

- `{rounded.xs}` for segments and small chips, `{rounded.sm}` for tiles and buttons, `{rounded.md}` for rows and cards, `{rounded.lg}` for dialogs, `{rounded.xl}` for hero icon tiles.
- Circles are reserved for the PIN dots and the shield mark; they do not decorate ordinary controls.
- One radius per surface — a container and its border share the same value, and inner segments step down exactly one level.

## Components

- **Photo tile:** square on `{components.photo-tile.backgroundColor}` with a 1px `{colors.border}` hairline and `{components.photo-tile.rounded}` corners. Hover and press respond with scale and border color only, never with a filled state.
- **Folder item:** `{components.folder-item.rounded}` row with a square cover thumbnail. The selected row takes `{components.folder-item.backgroundColor}` and `{components.folder-item.textColor}`; unselected rows have no background.
- **Segmented control:** `{components.segmented-control.backgroundColor}` track with a 1px `{colors.border}` outline and `{components.segmented-control.rounded}` corners; the active segment inverts to `{colors.primary}` on `{colors.surface}` with `{rounded.xs}`. Used for grid density and auth tabs.
- **Dialog:** `{components.dialog.backgroundColor}` on `{components.dialog.rounded}` corners, with a title row, one divider, content, and a metadata footer carrying the single primary action.
- **Media viewer:** fullscreen on `{components.media-viewer.backgroundColor}` with white chrome over a `{colors.scrim}` gradient; interactive zoom stays inside the media area.
- **Feedback:** progress is a 2px linear bar under the app bar for pane-level loads, and an inline spinner in the control that triggered the work.

## Do's and Don'ts

- Do limit the view to one `{colors.primary}` usage; a segmented control, a text link, and a filled action in the same view each dilute the others.
- Do place validation and failure text next to the control that failed, in `{colors.danger}`.
- Do give every empty state one clear next action.
- Do keep interaction feedback at or under 200ms, ease-out, on transform and opacity only.
- Don't animate layout properties — width, height, margin, padding, or top/left offsets.
- Don't add gradients, except the scrim behind fullscreen media.
- Don't introduce purple, multicolor gradients, or a second accent hue.
- Don't use glows or colored shadows as affordances.
- Don't tint whole surfaces to signal state; use `{colors.border}` and `{colors.surface-muted}`.
- Don't add motion that was not requested.
