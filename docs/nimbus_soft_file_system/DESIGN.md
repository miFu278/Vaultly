---
name: Nimbus Soft File System
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#434655'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#9d4300'
  on-secondary: '#ffffff'
  secondary-container: '#fd761a'
  on-secondary-container: '#5c2400'
  tertiary: '#006242'
  on-tertiary: '#ffffff'
  tertiary-container: '#007d55'
  on-tertiary-container: '#bdffdb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#ffdbca'
  secondary-fixed-dim: '#ffb690'
  on-secondary-fixed: '#341100'
  on-secondary-fixed-variant: '#783200'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system embodies a modern, soft-tactile approach tailored for next-generation mobile cloud storage and personal file management. Blending clean Scandinavian minimalism with soft, neumorphic-tinted surface softness, the visual language establishes a sense of spaciousness, calm organization, and effortless control.

The personality is friendly, organized, trustworthy, and premium. Rather than cold utility, file organization feels as tactile and satisfying as handling physical stationeries or modular studio trays. Target users include digital creators, remote professionals, and everyday mobile users seeking friction-free asset backup and organization.

Key aesthetics include:
- Soft off-white and cool mist backdrops (`#F4F6FA` to `#F8FAFD`) delivering an airy canvas that reduces eye strain.
- Ultra-soft, multi-stop diffusion shadows that impart a pillowy, floating elevation to card containers.
- Playful, vibrant category accents featuring gradient transitions in azure, tangerine, jade, and iris to immediately distinguish file buckets (media, documents, archives, audio).
- High visual delight through circular segmented storage meters, squircle-shaped folder jackets, and frosted floating bottom navigation capsules.

## Colors

The palette balances clean, low-saturation canvas tones with expressive, luminous functional accents.

### Core Canvas & Neutrals
- **Surface Canvas**: `#F4F6FA` provides a soft, cool base contrast against pure white cards.
- **Surface Card**: `#FFFFFF` pure white cards pop subtly against the backdrop.
- **Surface Inset / Input**: `#EDF2F7` used for search bars, inner track meters, and indented containers.
- **Text Primary**: `#0F172A` deep obsidian slate for crisp legibility.
- **Text Secondary**: `#64748B` cool neutral slate for metadata, time stamps, and counters.
- **Text Tertiary / Muted**: `#94A3B8` for disabled indicators and subtle labels.

### Vibrant Category Accents & Gradients
The accent spectrum maps directly onto file categorization:
- **Blue (Documents & Primary Actions)**: `#2563EB` transitioning to `#38BDF8`.
- **Orange (Videos & Cloud Sync)**: `#EA580C` transitioning to `#F97316`.
- **Green (Images & Progress Indicators)**: `#059669` transitioning to `#10B981` or `#84CC16`.
- **Violet (Audio & System Archives)**: `#7C3AED` transitioning to `#A855F7`.

Gradients should run diagonally at 135 degrees with smooth color interpolation. In charts and storage ring meters, adjacent arcs terminate with rounded stroke caps.

## Typography

The typographic hierarchy pairs the friendly, organic geometry of **Plus Jakarta Sans** for brand headings, titles, and body content with the systematic precision of **Inter** for technical metadata, numeric units, and compact UI tags.

- **Numerals & Metrics**: Center statistics (such as `27%` inside donut gauges, storage quotas `120.3 GB`) use `Plus Jakarta Sans` in bold weights (`700`), ensuring rapid visual digestion.
- **File Metadata**: Timestamps, item counts, and file extensions leverage `Inter` (`label-md` and `label-sm`) with tabular figures enabled (`font-feature-settings: 'tnum'`) to maintain clean baseline alignment in multi-column lists and folder grids.
- **Letter Spacing**: Maintain tight tracking (`-0.02em`) on display headlines to reinforce the modern soft aesthetic, while keeping labels at neutral to slightly expanded (`+0.01em`) tracking for legibility at small scale.

## Layout & Spacing

The layout model is optimized for mobile-first handheld workflows while seamlessly adapting across wider viewports.

### Grid & Margins
- **Mobile (Base)**: Single-column scroll with a standard outer margin of `1.25rem` (`20px`) and `1rem` (`16px`) gutters between folder tiles and modular widgets.
- **Folder Grids**: Uses a balanced 2-column or 3-column fluid grid on mobile devices. Columns collapse or expand depending on view density modes.
- **Tablet / Large Screens**: Converts to a 6-to-12 column layout with a fixed primary navigation rail and maximum content container width of `1040px` to maintain focused density.

### Spacing Density
- Container internal paddings honor `space-md` (`16px`) to `space-lg` (`24px`), giving widgets generous breathing room.
- Related elements (e.g., folder icon badge + title) use `space-sm` (`8px`), while discrete sections (e.g., storage ring gauge to folder directory) use `space-xl` (`32px`).

## Elevation & Depth

Visual depth is achieved through ambient, diffused dropshadows, subtle light bevels, and micro-neumorphic inset fields rather than high-contrast structural borders.

### Elevation Hierarchy
- **Level 0 (Base Canvas)**: Neutral canvas `#F4F6FA`. Flat with zero shadow.
- **Level 1 (Inset / Grooves)**: Search fields, storage progress tracks, and inactive chips use subtle inner shadows (`inset 0 2px 4px rgba(15, 23, 42, 0.04)`) with an `#EDF2F7` fill to appear physically recessed into the canvas.
- **Level 2 (Cards & Modules)**: Pure white cards `#FFFFFF` elevated via a dual-layered diffused shadow:
  - Ambient: `0 10px 25px -5px rgba(30, 41, 59, 0.05)`
  - Edge: `0 2px 6px -1px rgba(30, 41, 59, 0.02)`
- **Level 3 (Interactive Folder Jackets & Active Chips)**: Hovered or selected folder cards lift with an amplified ambient glow:
  - `0 16px 32px -8px rgba(37, 99, 235, 0.12), 0 4px 12px -2px rgba(15, 23, 42, 0.04)`
- **Level 4 (Floating Navigation Dock)**: The bottom capsule bar floats above content with a high-diffusion elevation combined with subtle glassmorphism (`backdrop-filter: blur(20px)` at 90% opacity):
  - `0 20px 40px -10px rgba(15, 23, 42, 0.12), 0 1px 3px rgba(255, 255, 255, 0.8) inset`

## Shapes

The shape system adopts smooth, exaggerated corner curvature (24px to 32px), creating a friendly, modern handheld pebble profile.

- **Primary Cards & Containers**: Use `24px` to `28px` corner radius.
- **Folder Graphics & Tabs**: Features asymmetric squircle curves—the top tab displays rounded peaks with smooth transitions into the card body.
- **Buttons, Badges & Floating Dock**: Pill-shaped (`9999px` / `rounded-full`) for high clickability and tactile softness.
- **Icon Badges**: `16px` to `20px` squircle containers surrounding crisp 3D/duotone category icons.

## Components

### Buttons & Action Pills
- **Primary Action**: Pill-shaped button with solid primary blue or subtle gradient (`#2563EB` to `#1D4ED8`), white text (`Plus Jakarta Sans 600`), and a soft tinted shadow (`0 8px 16px -4px rgba(37, 99, 235, 0.35)`).
- **Secondary / Icon Buttons**: White circle (`44px × 44px`) or squircle container with ambient drop shadow, housing centered monochrome slate icons.
- **Micro Navigation Pills**: Inset capsule buttons with active indicator sliding background.

### Folder Cards & Storage Containers
- **Folder Card**: Dual-layered construction. A colored gradient backdrop sleeve (blue, orange, green, violet) peeking behind a pure white foreground flap, giving the visual impression of a physical organizer folder.
- **Storage Donut Gauge**:
  - Segmented ring with rounded terminal caps.
  - Multi-colored segments mapping to category tokens (blue for video, orange for apps/docs, green for photos).
  - Center cutout displaying large metric callout (`27%`) above secondary descriptor (`120.3 of 254 GB used`).

### Progress Trackers
- Horizontal segmented bars with fully rounded ends (`16px` pill height).
- Background track set to `#E2E8F0` inset.
- Fill uses vivid gradient fills (e.g., lime-to-emerald gradient) indicating completion percentage.

### Search Field
- Pill-shaped (`rounded-full`) `#FFFFFF` or `#EDF2F7` surface with a subtle inset feel.
- Left-aligned search glass icon in `#94A3B8`, placeholder text in `#64748B`.
- Integrated voice or filter pill on the right boundary.

### Floating Bottom Navigation Bar
- Autonomous floating capsule suspended `16px` above the bottom screen safe area.
- Pure white with frosted blur (`backdrop-filter: blur(16px)`).
- Active item displays an illuminated tinted squircle badge (`#F1F5F9` or soft brand tint) behind the icon.