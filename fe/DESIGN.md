---
version: beta
name: Vaultly
description: Neumorphic (soft-UI) design language for the Vaultly secure photo vault (Flutter web + Android).
colors:
  background: "#E8EDF3"
  surface: "#E8EDF3"
  surface-muted: "#E0E6ED"
  media-canvas: "#DDE4EC"
  border: "#D5DDE6"
  foreground: "#2C333D"
  foreground-muted: "#555F6B"
  primary: "#2C333D"
  danger: "#AE2F2A"
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
  xs: 10px
  sm: 12px
  md: 14px
  lg: 18px
  xl: 24px
  pill: 999px
depth:
  light-from: top-left
  raised-offset: 5px
  raised-blur: 10px
  raised-color-light: "rgba(163, 177, 198, 0.30)"
  raised-highlight-light: "rgba(255, 255, 255, 0.80)"
  raised-color-dark: "rgba(0, 0, 0, 0.40)"
  raised-highlight-dark: "rgba(255, 255, 255, 0.08)"
  inset-shade-light: "rgba(0, 0, 0, 0.07)"
  inset-sheen-light: "rgba(255, 255, 255, 0.70)"
  inset-shade-dark: "rgba(0, 0, 0, 0.32)"
  inset-sheen-dark: "rgba(255, 255, 255, 0.05)"
  hover-lift: 1.4
  pressed-scale: 0.97
motion:
  fast: 130ms
  medium: 200ms
  ease: ease-out
spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  touch-target: 44px
  pane-breakpoint: 680px
  sidebar-collapsed: 68px
  sidebar-expanded: 250px
  form-max: 440px
  dialog-max: 800px
components:
  photo-tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.sm}"
    depth: 0.8
  folder-item:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.md}"
    depth: 0.55
  segmented-control:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.md}"
    inset: true
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
    depth: 1.4
  media-viewer:
    backgroundColor: "{colors.media-canvas}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.xl}"
---

## Overview

Vaultly is a cross-platform secure photo vault: folders of encrypted images, opened with an account and a 6-digit PIN. The interface uses **Neumorphism (soft UI)**: the canvas and every surface share one base tone, and shapes are separated only by a paired light/dark shadow — never by borders or fills.

The light comes from the **top-left**. A raised element casts a dark shadow to the bottom-right and a light highlight to the top-left; a pressed, selected, or grouped element is debossed into the canvas instead. Chrome stays quiet and physical so the photos remain the only saturated content on screen.

## Colors

The palette is monochrome by design; there is no chromatic brand color.

- **Background (#E8EDF3):** App canvas.
- **Surface (#E8EDF3):** Identical to background — this is required. Neumorphism collapses without a shared base tone; never "fix" a surface by tinting it.
- **Surface muted (#E0E6ED):** Debossed wells, grouped controls, recessed input fields, and the debossed end of the press gradient.
- **Media canvas (#DDE4EC):** The well behind fullscreen/dialog media.
- **Border (#D5DDE6):** Only the 1px inner hairline of a debossed well, so a recess never disappears at low contrast. Never used as an outer edge.
- **Foreground (#2C333D):** Primary text, icons, and the ink of the single primary action.
- **Foreground muted (#555F6B):** Secondary text, metadata, inactive icons, placeholders, unselected segments.
- **Primary (#2C333D):** Identical to foreground. The one ink-filled action in a view.
- **Danger (#AE2F2A):** Validation, failure text, and destructive actions only.
- **Scrim (#000000):** Only behind fullscreen media and modals.

## Themes

Light is the default theme; dark reuses every token name with the values below. Theme switching must change values only — never introduce separate `-light`/`-dark` token names or a second palette.

| Token | Light (default) | Dark |
|---|---|---|
| `colors.background` | `#E8EDF3` | `#23262B` |
| `colors.surface` | `#E8EDF3` | `#23262B` |
| `colors.surface-muted` | `#E0E6ED` | `#1E2126` |
| `colors.media-canvas` | `#DDE4EC` | `#191B1F` |
| `colors.border` | `#D5DDE6` | `#2E3238` |
| `colors.foreground` | `#2C333D` | `#E8EAED` |
| `colors.foreground-muted` | `#555F6B` | `#9BA3AE` |
| `colors.primary` | `#2C333D` | `#E8EAED` |
| `colors.danger` | `#AE2F2A` | `#FF6B6B` |
| `colors.scrim` | `#000000` | `#000000` |

In dark mode the light source does not move: the dark shadow stays black and the highlight becomes a faint white sheen on the same base tone.

**Contrast is a hard requirement, not a preference.** Soft same-tone surfaces are exactly where text silently drops below readable contrast:

- Body, metadata, and error text must hold **≥ 4.5:1** against `background`, `surface`, `surface-muted`, **and the debossed end of an inset well**.
- Meaningful icons and control outlines must hold **≥ 3:1**.
- `test/neumorphic_test.dart` asserts these ratios for both themes. A token change that breaks one fails the suite — fix the token, never the assertion.

## Typography

One system font family, differentiated by size and weight alone.

- **Brand and titles:** use `brand`, `title`, and `title-lg` with negative tracking. Tighten tracking only on these; leave body and label text untouched.
- **Body and labels:** `body` for row text and list items, `label` for metadata rows, `caption` and `micro` for counts, badges, and tile overlays.
- **Weights:** 700 only for the brand mark and the auth hero, 600 for section titles, primary actions, and row titles, 500 for everything else. Never exceed three weights in one view.
- **Numbers:** counts, file sizes, and dates use tabular figures so they do not shift between rows.
- **Density:** every title truncates to a single line with an ellipsis; never wrap a title to a second line to fit a control.

## Depth

All depth tokens live in `AppShadows` (`lib/theme/app_tokens.dart`) and every surface is rendered by the single `Neumorphic` primitive (`lib/widgets/neumorphic.dart`). Do not hand-write shadows in a component.

- **Raised (resting):** two shadows — dark at `+offset`, highlight at `-offset`, offset `5 × depth` px, blur `10 × depth` px. `depth` is hierarchy: `0.55` sidebar rows, `0.7` toolbars/chips, `0.8` photo tiles, `1.0` default, `1.4` dialogs and sheets.
- **Raised (hover, pointer devices only):** `depth × 1.4`. Same tone, same shape, no layout shift.
- **Pressed / selected / disabled:** debossed — a `top-left → bottom-right` linear gradient from `inset-shade` to `inset-sheen` over the base tone, plus a soft inner shadow and the 1px `border` hairline. A press also scales to `0.97`. This is the neumorphic replacement for a ripple; Material ink splashes must not appear on a neumorphic surface.
- **Recessed wells:** the same deboss treatment at the container level — segmented tracks, PIN dots, text fields, cover thumbnails, media wells inside dialogs.

Timing is shared: `AppMotion.fast` (130ms) for press and hover feedback, `AppMotion.medium` (200ms) for surface/selection changes, always `ease-out`, always on transform/opacity — never on layout properties. Honor reduced motion.

## Layout

An 8px rhythm with 4px (`{spacing.xs}`) and 2px (`{spacing.xxs}`) half-steps for icon and segment gaps.

- **Two-pane:** at or above `{spacing.pane-breakpoint}` show the folder sidebar beside the photo grid, sidebar at `{spacing.sidebar-expanded}` and `{spacing.sidebar-collapsed}` when collapsed. The desktop sidebar is a raised panel inset `{spacing.sm}` from every edge; the mobile drawer is edge-to-edge and flat.
- **One-pane:** below `{spacing.pane-breakpoint}` move the sidebar into a drawer and keep the grid full width.
- **Left-anchored chrome:** the app bar and pane headers align left; the app bar is a single row of controls, never a second toolbar.
- **Constrained content:** centered forms cap at `{spacing.form-max}`; dialogs cap at `{spacing.dialog-max}`.
- **Grid:** square tiles in 2 to 4 columns with `{spacing.sm}` gutters and `{spacing.md}` page padding; the column count is the only density control.
- **Insets:** every fixed bar respects the device safe area; full-height layouts are sized from the available viewport, never from a fixed screen height.
- **Touch targets:** interactive surfaces are at least `{spacing.touch-target}` — expand the hit area when the glyph is smaller.

## Shapes

Radii are generous and consistent; the soft-UI band is 10–14px, and surfaces scale up from there.

- `{rounded.xs}` for segments and compact chips, `{rounded.sm}` for tiles and small buttons, `{rounded.md}` for rows, toolbars, keypad keys, and dialogs, `{rounded.lg}` for the sidebar panel and sheets, `{rounded.xl}` for the auth hero tile and bottom-sheet top corners.
- `{rounded.pill}` for chips, badges, status pills, icon buttons, and PIN dots. Round is a shape, not decoration.
- One radius per surface; a container and its debossed well step down exactly one level.

## Components

- **Photo tile:** `Neumorphic` at `depth 0.8` with a 3px inset frame, so the thumbnail sits inside an extruded bezel. Hover lifts the depth; press debosses it. Selection is a debossed tile plus a check badge — never a color-only change.
- **Video tile:** a poster-less card inside a debossed well — extruded play disc, file name, file size. Video tiles must never go through `Image.network`: `/files/{id}/view` returns the decrypted video stream, so the tile would download the whole file only to fail decoding. Add a server-side poster frame before rendering real thumbnails here.
- **Video player:** neumorphic well + transport bar showing play/pause, a scrubbable position slider, and tabular position/duration. Controls sit **below** the video, never on top of it: on Flutter web the `<video>` element is a platform view that composites above the Flutter canvas, so an overlaid control would be invisible. The transport bar is the last element on a video page, so video pages reserve `filmstrip` height at the bottom and stay clear of the thumbnail strip.
- **Folder item:** raised `{components.folder-item.rounded}` row at `depth 0.55` with a debossed square cover thumbnail. The selected row is debossed, not tinted.
- **Segmented control:** one debossed track (`inset: true`) holding a single raised segment for the active value. Used for grid density and auth tabs. Unselected labels are `foreground-muted` and sit on the well, so the muted token must clear 4.5:1 on the debossed end.
- **Toolbar:** the grid sub-header floats as a raised panel inset `{spacing.md}` from the pane edges, carrying the density control and any selection actions.
- **Bottom sheet:** a raised `depth 1.4` panel with `{rounded.xl}` top corners; rows are individual raised tiles, not `ListTile`s.
- **Dialog:** `NeumorphicDialog` — transparent Material frame plus one raised `depth 1.4` `{rounded.lg}` panel. Title row, hairline divider, content, metadata footer carrying the single primary action.
- **Media viewer:** fullscreen on `{components.media-viewer.backgroundColor}` with white chrome over a `{colors.scrim}` gradient; interactive zoom stays inside the media area. Neumorphic depth is suppressed in the chrome — shadows read as noise over a scrim — and is used only for the floating play control over the media itself.
- **Disabled control:** debossed with muted text and no tap action. Never a ghosted-but-raised control.
- **Feedback:** progress is a 3px linear bar under the app bar for pane-level loads, and an inline spinner inside the control that triggered the work.

## Do's and Don'ts

- Do render every extruded or debossed surface through `Neumorphic`; do not hand-roll `BoxDecoration` shadows per screen.
- Do keep `surface` and `background` the same value in both themes.
- Do express state as **depth + emphasis + icon**, so state survives without color.
- Do limit the view to one ink-filled primary action; every other control is same-tone raised.
- Do place validation and failure text next to the control that failed, in `{colors.danger}`, and keep it at 4.5:1.
- Do give every empty state one clear next action.
- Do keep interaction feedback at or under 200ms, ease-out, on transform and opacity only.
- Don't add outer borders, dividers on shapes, or drop shadows to separate two surfaces — depth does that.
- Don't animate layout properties — width, height, margin, padding, or top/left offsets.
- Don't use glows or colored shadows as affordances.
- Don't introduce gradients except the debossed inset gradient, the media scrim, and the viewer chrome scrim.
- Don't introduce a second accent hue; `{colors.danger}` is the only exception and only on the failing control.
- Don't use Material ink splashes on a neumorphic surface; the raised → debossed transition is the press state.
- Don't add motion that was not requested.
