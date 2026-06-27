# DESIGN.md — Apple / UIKit & SwiftUI Edition

A format specification for describing a visual identity to coding agents building **native Apple apps**. DESIGN.md gives an agent a persistent, structured understanding of a design system so that it can be followed across sessions and between different AI agents and tools — and rendered idiomatically with **SwiftUI** and **UIKit** rather than CSS.

This is an Apple-platform adaptation of [DESIGN.md](https://github.com/google-labs-code/design.md). The core idea is unchanged: **machine-readable tokens carry exact values; human-readable prose carries the intent.** What changes here is the vocabulary — points instead of pixels, Dynamic Type instead of fixed `rem`, semantic system colors, materials, SF fonts, and Swift export targets.

## The Format

A DESIGN.md file combines machine-readable design tokens (YAML front matter) with human-readable design rationale (markdown prose). Tokens give agents exact values. Prose tells them *why* those values exist and how to apply them on iOS, iPadOS, macOS, watchOS, tvOS, and visionOS.

```md
---
name: Heritage
platform:
  os: [iOS, iPadOS]
  minimumDeployment: "17.0"
  appearance: [light, dark]
colors:
  primary:
    light: "#1A1C1E"
    dark: "#F2F2F7"
  secondary: "#6C7278"
  tertiary: "#B8422E"
  neutral:
    light: "#F7F5F2"
    dark: "#1C1B19"
typography:
  largeTitle:
    fontFamily: SF Pro
    textStyle: largeTitle      # Dynamic Type ramp this scales on
    fontSize: 34pt             # base size at the .large content size
    fontWeight: 600
  body:
    fontFamily: SF Pro
    textStyle: body
    fontSize: 17pt
  caption:
    fontFamily: SF Mono
    textStyle: caption1
    fontSize: 12pt
rounded:
  sm: 6pt
  md: 12pt
  curve: continuous            # RoundedRectangle corner style
spacing:
  sm: 8pt
  md: 16pt
---

## Overview

Architectural Minimalism meets Journalistic Gravitas. The UI evokes a
premium matte finish — a high-end broadsheet rendered as a native iOS app.
It reads as a System app, not a web view: standard navigation, large titles,
Dynamic Type honored everywhere.

## Colors

The palette is rooted in high-contrast neutrals and a single accent color,
expressed as light/dark pairs so the system resolves them automatically.

- **Primary (#1A1C1E / #F2F2F7):** Deep ink for headlines and core text;
  inverts to near-white in Dark Mode.
- **Secondary (#6C7278):** Sophisticated slate for separators, captions,
  and secondary labels.
- **Tertiary (#B8422E):** "Boston Clay" — the app's single accent, used as
  the `.tint` for interactive controls.
- **Neutral (#F7F5F2 / #1C1B19):** Warm limestone foundation, softer than
  `systemBackground`, used as the grouped-content background.
```

An agent that reads this file will produce a SwiftUI app with deep-ink large titles in SF Pro, a warm limestone `background`, a Boston Clay `.tint(...)`, and full Dark Mode support — because each token resolves to the right native primitive.

## Why an Apple-specific edition

The original DESIGN.md was written with the web in mind: `px`/`rem` units, `font-feature-settings`, Tailwind export, WCAG sRGB contrast. Native Apple UI has a different — and largely richer — set of primitives. This edition maps the format onto them so an agent doesn't have to guess:

- **Points, not pixels.** All dimensions are in `pt`. The system handles `@2x`/`@3x` rasterization; you never specify device pixels.
- **Dynamic Type, not fixed sizes.** A `fontSize` is the *base* size at the default content-size category. The `textStyle` token names which Dynamic Type ramp it scales along, so text grows and shrinks with the user's accessibility setting.
- **Semantic & adaptive color.** Colors may be a single value or a `{ light, dark }` (and optional `{ highContrast }`) pair. Token names may also reference Apple's semantic system colors (`label`, `systemBackground`, `separator`, …) instead of literal hex.
- **Materials & Liquid Glass.** Elevation is expressed with system materials and vibrancy, not just drop shadows.
- **Continuous corners.** Apple's hardware uses superellipse ("squircle") corners; the `rounded.curve: continuous` token captures this so `RoundedRectangle(cornerRadius:style:)` is generated with `.continuous`.
- **Swift export.** Tokens export to a `Theme.swift`, `Color`/`Font` extensions, and Asset Catalog color sets — not a Tailwind config.

Everything else — the prose-first philosophy, the section order, the `{path.to.token}` reference syntax, the "unknown content" tolerance — is preserved exactly.

## The Specification

A DESIGN.md file has two layers:

1. **YAML front matter** — Machine-readable design tokens, delimited by `---` fences at the top of the file.
2. **Markdown body** — Human-readable design rationale organized into `##` sections.

The tokens are the normative values. The prose provides context for how to apply them. Prose may use descriptive names ("Boston Clay") that correspond to systematic token names (`tertiary`).

### Token Schema

```yaml
version: <string>            # optional, current: "alpha-apple"
name: <string>
description: <string>        # optional
platform:                    # optional, Apple-specific
  os: <[iOS | iPadOS | macOS | watchOS | tvOS | visionOS]>
  minimumDeployment: <string>   # e.g. "17.0"
  appearance: <[light, dark]>
colors:
  <token-name>: <Color | AdaptiveColor>
typography:
  <token-name>: <Typography>
rounded:
  <scale-level>: <Dimension>
  curve: <continuous | circular>   # optional corner-curve style
spacing:
  <scale-level>: <Dimension | number>
materials:                   # optional, Apple-specific
  <token-name>: <Material>
components:
  <component-name>:
    <token-name>: <string | token reference>
```

### Token Types

| Type | Format | Example |
|:-----|:-------|:--------|
| Color | Any valid color string (hex, sRGB, **Display P3**, named) | `"#1A1C1E"`, `"p3(0.72 0.26 0.18)"`, `label` |
| AdaptiveColor | Object with `light`, `dark`, optional `highContrast`/`elevated` | `{ light: "#1A1C1E", dark: "#F2F2F7" }` |
| Dimension | number + unit, where the unit is **`pt`** (points) | `12pt`, `-0.4pt` (tracking) |
| Token Reference | `{path.to.token}` | `{colors.tertiary}` |
| Typography | object — see below | See example |
| Material | A system material name | `regular`, `thin`, `ultraThin`, `glass` |

> **Units.** Use `pt` for every dimension (sizes, spacing, radii, tracking). Web units (`px`, `rem`, `em`) are not used on Apple platforms. A unitless `lineHeight`/`spacing` number is still allowed and means a multiplier or a raw point count, as noted per field.

### Typography fields

A Typography token describes one type level. Fields map to SwiftUI `Font` / UIKit `UIFont` primitives:

- `fontFamily` (string) — e.g. `SF Pro`, `SF Pro Rounded`, `SF Mono`, `New York`, or a bundled custom family. Use `SF Pro` (the system font) unless the brand requires otherwise.
- `textStyle` (string) — the **Dynamic Type** ramp this level scales along: `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `body`, `callout`, `footnote`, `caption1`, `caption2`. Generates `.font(.largeTitle)` etc. and lets the level respond to the user's text-size setting.
- `fontSize` (Dimension, `pt`) — the base size at the default (`.large`) content-size category. With `textStyle` present, this is the anchor the ramp scales from; without it, it is a fixed size (`.system(size:)`).
- `fontWeight` (number | name) — `400`/`regular`, `600`/`semibold`, `700`/`bold`; maps to `Font.Weight`.
- `fontDesign` (string) — `default`, `rounded`, `serif`, `monospaced`; maps to `Font.Design`. (`SF Pro Rounded` ≈ `fontDesign: rounded`; `New York` ≈ `serif`.)
- `lineHeight` (Dimension | number) — a `pt` value sets an explicit line height; a unitless number multiplies `fontSize`. Realized via `.lineSpacing(...)` or a paragraph style.
- `tracking` (Dimension, `pt`) — per-character spacing; maps to `.tracking(...)`. (Replaces web `letterSpacing`.)
- `kerning` (Dimension, `pt`) — pair kerning; maps to `.kerning(...)`. Prefer `tracking` for uniform spacing.
- `monospacedDigit` (boolean) — when `true`, generates `.monospacedDigit()` for tabular numerals (timers, metrics, prices).

> **Casing.** Express uppercase/lowercase intent in prose ("labels are uppercase") and via `.textCase(.uppercase)` in components — there is no casing token, matching the web spec.

### Color: adaptive and semantic

A color token may be:

- **A literal value** — hex (`"#1A1C1E"`), or a wide-gamut **Display P3** value for the saturated brand accents Apple displays support.
- **An adaptive pair** — `{ light, dark }`, optionally `{ highContrast, elevated }`. The agent generates an Asset Catalog color set (or a dynamic `UIColor`/`Color`) so the system resolves the right value automatically.
- **A semantic system color reference** — one of Apple's semantic colors by name: `label`, `secondaryLabel`, `tertiaryLabel`, `systemBackground`, `secondarySystemBackground`, `systemGroupedBackground`, `separator`, `opaqueSeparator`, `link`, `systemFill`, plus the system tints (`systemBlue`, `systemRed`, …). Prefer these for chrome and text so the app inherits correct contrast in every appearance automatically.

All color values are converted to sRGB for contrast checking; the original format (including P3) is preserved for display and export.

### Section Order

Sections use `##` headings. They can be omitted, but those present must appear in this order. (Same order as the base spec; "Elevation & Depth" covers shadows **and materials**.)

| # | Section | Aliases |
|:--|:--------|:--------|
| 1 | Overview | Brand & Style |
| 2 | Colors | |
| 3 | Typography | |
| 4 | Layout | Layout & Spacing |
| 5 | Elevation & Depth | Elevation, Materials |
| 6 | Shapes | |
| 7 | Components | |
| 8 | Do's and Don'ts | |

Unknown sections are preserved, not errored — so Apple-specific sections like `## Motion`, `## SF Symbols`, `## Haptics`, or `## App Icon` slot in naturally (see *The format grows through its users*).

## Sections in Apple terms

### Overview

A holistic description of the product's look and feel: brand personality, audience, and the emotional response the UI should evoke. On Apple platforms, also state **how native it should feel** — does it lean on standard system components and navigation (a "System app"), or is it a custom-drawn, brand-forward surface? This is the single most load-bearing section. A specific reference ("feels like the Apple Notes app, but for field biologists") carries more than a list of adjectives.

### Colors

Define at least `primary`. Common roles, in order: `primary`, `secondary`, `tertiary`, `neutral`, plus semantic surfaces (`surface`, `onSurface`, `error`). Provide `{ light, dark }` pairs for anything that isn't already a system semantic color. The app's accent maps to the SwiftUI `.tint(...)` / global `accentColor`.

```yaml
colors:
  primary:    { light: "#1A1C1E", dark: "#F2F2F7" }
  secondary:  "#6C7278"
  tertiary:   "#B8422E"               # the app tint
  neutral:    { light: "#F7F5F2", dark: "#1C1B19" }
  surface:    systemBackground        # semantic system color
  onSurface:  label
  separator:  separator
```

### Typography

Most systems define 9–15 levels. Name them by Dynamic Type role (`largeTitle`, `title`, `headline`, `body`, `callout`, `footnote`, `caption`) so each maps cleanly onto a system text style and scales with accessibility settings.

```yaml
typography:
  largeTitle:
    fontFamily: SF Pro
    textStyle: largeTitle
    fontSize: 34pt
    fontWeight: 700
  body:
    fontFamily: SF Pro
    textStyle: body
    fontSize: 17pt
    fontWeight: 400
  metric:
    fontFamily: SF Mono
    textStyle: caption1
    fontSize: 12pt
    fontWeight: 500
    tracking: 0.5pt
    monospacedDigit: true
```

Prose tells the agent the intent:

> Headlines are SF Pro Semibold to read as institutional and trustworthy. Body is SF Pro Regular at the system `body` size for long-form readability. Metrics and timestamps use SF Mono with monospaced digits so numbers don't jitter as they update.

### Layout

Describe the spacing strategy in native terms: **safe areas**, **layout margins** (`.safeAreaInset`, `layoutMargins`, the readable content guide), and stack/grid spacing. Most Apple layouts are built from `VStack`/`HStack`/`Grid` with a consistent spacing scale rather than a fixed column grid.

```yaml
spacing:
  base: 16pt
  xs: 4pt
  sm: 8pt
  md: 16pt
  lg: 24pt
  xl: 32pt
  gutter: 16pt        # default content inset
  section: 35pt       # grouped-list section spacing
```

> Built from an 8pt rhythm with a 4pt half-step. Content respects the safe area and the readable-width guide on iPad. Related items are grouped into cards with 16pt internal padding, echoing inset grouped lists.

### Elevation & Depth — Materials

This is where the Apple edition diverges most. Depth is conveyed primarily through **system materials** and **vibrancy**, with shadows as a secondary, restrained tool.

```yaml
materials:
  bar:     regular      # navigation/tab bars
  sheet:   thick        # sheets, popovers
  overlay: ultraThin    # transient overlays
  glass:   glass        # Liquid Glass surface (where supported)
```

Material values map to SwiftUI: `ultraThin` → `.ultraThinMaterial`, `thin` → `.thinMaterial`, `regular` → `.regularMaterial`, `thick` → `.thickMaterial`, plus `bar` materials and Liquid `glass`. Prose example:

> Depth comes from **layered materials**, not heavy shadows. Bars and sheets use system materials so content blurs behind them; foreground vibrant text and symbols sit on those materials via `.foregroundStyle(.secondary)`. Use a shadow only to lift a single floating action element, never on list rows or cards.

### Shapes

Describe the shape language and capture corner radii plus the **corner curve**. Apple UI uses continuous (superellipse) corners almost everywhere; say so.

```yaml
rounded:
  sm: 6pt
  md: 12pt
  lg: 20pt
  capsule: 9999pt     # use Capsule() in SwiftUI
  curve: continuous   # RoundedRectangle(cornerRadius:style: .continuous)
```

> Interactive elements use a 12pt **continuous** corner radius — the squircle curve the system uses for app icons and cards — never sharp corners. Pills and segmented controls use `Capsule()`. Concentric radii: a control inside a card uses a smaller radius than the card so corners nest cleanly.

### Components

Map a component name to a group of sub-token properties. On Apple platforms, components correspond to SwiftUI controls / `ButtonStyle`s / UIKit appearance proxies. Common types: **Buttons** (`.borderedProminent`, `.bordered`, `.plain`), **Toggles**, **Pickers / segmented controls**, **Lists & rows** (`.insetGrouped`), **TextFields**, **Tab bars / Navigation bars**, **Sheets**, **SF Symbols** usage.

Valid component properties (Apple-flavored):

- `backgroundColor: <Color>`
- `foregroundColor: <Color>` *(alias: `textColor`, for label/symbol color — `foregroundStyle`)*
- `tint: <Color>` — the control's accent (`.tint(...)`)
- `typography: <Typography>`
- `rounded: <Dimension>`
- `material: <Material>`
- `padding: <Dimension>`
- `size` / `height` / `width: <Dimension>`
- `symbolWeight: <string>` — SF Symbols weight (`regular`, `semibold`, …)
- `controlSize: <string>` — `mini` | `small` | `regular` | `large` (`.controlSize(...)`)

Variants (pressed, disabled, selected, hover on iPad/macOS) are separate entries with a related key:

```yaml
components:
  button-primary:
    style: borderedProminent       # maps to .buttonStyle(.borderedProminent)
    tint: "{colors.tertiary}"
    foregroundColor: "{colors.neutral}"
    rounded: "{rounded.md}"
    controlSize: large
    typography: "{typography.body}"
  button-primary-pressed:
    tint: "#9E3826"                 # darker on press
  button-primary-disabled:
    tint: "{colors.secondary}"
  list-row:
    backgroundColor: secondarySystemGroupedBackground
    foregroundColor: label
    padding: 16pt
```

### Do's and Don'ts

Practical guardrails, grounded in the **Human Interface Guidelines**:

```markdown
## Do's and Don'ts

- Do honor Dynamic Type — every text level scales; never hard-code a frame
  height that clips at larger accessibility sizes.
- Do provide light and dark values for every custom color; test both.
- Do use a single accent (.tint) and let system colors carry chrome.
- Do respect the safe area and the readable content guide on iPad.
- Don't disable Dynamic Type or use fixed `.system(size:)` for body text.
- Don't put a drop shadow on list rows or cards — use materials and separators.
- Don't mix continuous and sharp corners in the same view.
- Don't override the system back gesture or hide standard navigation affordances.
- Don't tint text in the accent color for non-interactive labels.
```

## Worked Example

A complete, minimal DESIGN.md for an Apple app:

```md
---
name: Tide
platform:
  os: [iOS, iPadOS]
  minimumDeployment: "17.0"
  appearance: [light, dark]
colors:
  primary:   { light: "#0B3D52", dark: "#7FC9E8" }
  accent:    "p3(0.0 0.62 0.78)"
  surface:   systemGroupedBackground
  card:      { light: "#FFFFFF", dark: "#1C1C1E" }
  onSurface: label
  separator: separator
typography:
  largeTitle: { fontFamily: SF Pro, textStyle: largeTitle, fontSize: 34pt, fontWeight: 700 }
  headline:   { fontFamily: SF Pro, textStyle: headline, fontSize: 17pt, fontWeight: 600 }
  body:       { fontFamily: SF Pro, textStyle: body, fontSize: 17pt }
  reading:    { fontFamily: New York, textStyle: body, fontSize: 17pt, fontDesign: serif }
  metric:     { fontFamily: SF Mono, textStyle: caption1, fontSize: 12pt, monospacedDigit: true }
rounded:
  md: 12pt
  curve: continuous
spacing:
  sm: 8pt
  md: 16pt
  lg: 24pt
materials:
  bar: regular
components:
  button-primary:
    style: borderedProminent
    tint: "{colors.accent}"
    controlSize: large
    rounded: "{rounded.md}"
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.md}"
    padding: 16pt
---

## Overview

Tide is a calm tide-tracking app that should feel like a first-party Apple
Weather companion: large titles, generous whitespace, a single ocean-teal
accent, and information conveyed through type hierarchy rather than chrome.
It is unmistakably a System app — standard navigation, grouped lists, full
Dark Mode and Dynamic Type.

## Colors

Ocean-teal accent over neutral system surfaces.
- **Primary** {colors.primary} carries titles; inverts to a pale teal in dark.
- **Accent** {colors.accent} is the single interactive tint (Display P3 for a
  vivid teal on modern displays) — buttons, selection, links only.
- **Surface** {colors.surface} is the system grouped background; **Card**
  {colors.card} floats content above it.

## Typography

SF Pro for the interface, New York for long-form tide notes, SF Mono for
numeric readouts.
- Titles in SF Pro Bold at the `largeTitle` ramp.
- Tide heights use {typography.metric} so digits stay tabular as they tick.

## Elevation & Depth

Bars use the {materials.bar} system material so the chart scrolls under them.
No shadows on cards — separation comes from the card color over the grouped
background.

## Do's and Don'ts

- Do let the tide numbers use monospaced digits.
- Don't add a shadow under cards; the material and surface contrast suffice.
- Don't use the teal accent on any non-interactive text.
```

An agent reading this produces a SwiftUI app whose `Button` uses `.buttonStyle(.borderedProminent).tint(accent).controlSize(.large)`, whose cards are `RoundedRectangle(cornerRadius: 12, style: .continuous)`, whose navigation bar uses `.regularMaterial`, and whose tide readouts carry `.monospacedDigit()` — all in both appearances and at every Dynamic Type size.

## Export to Swift

Where the base spec exports to Tailwind, this edition exports to native Apple targets. (Tooling is illustrative — the format is the contract; an agent can generate these directly from the tokens.)

- **`Theme.swift` / `Color` & `Font` extensions** — strongly-typed accessors:

  ```swift
  extension Color {
      static let primary   = Color("primary")   // resolves from Asset Catalog
      static let accent    = Color(.displayP3, red: 0.0, green: 0.62, blue: 0.78)
  }
  extension Font {
      static let metric = Font.system(.caption, design: .monospaced).monospacedDigit()
  }
  ```

- **Asset Catalog color sets** — each adaptive `{ light, dark }` token becomes a `.colorset` with "Any" and "Dark" appearances, so the system resolves it for free.

- **`ShapeStyle` / `ButtonStyle` scaffolds** — component tokens become reusable styles (`PrimaryButtonStyle`, a `card` view modifier).

- **DTCG `tokens.json`** — the platform-neutral [W3C Design Tokens](https://tr.designtokens.org/format/) export is retained, so the same source can also feed Figma variables or a web sibling.

## The Linter

Validation is the same shape as the base spec — structural correctness, broken references, contrast — with Apple-aware rules:

| Rule | Severity | What it checks |
|:-----|:---------|:---------------|
| `broken-ref` | error | `{colors.accent}` references that don't resolve |
| `missing-primary` | warning | Colors defined but no `primary` |
| `contrast-ratio` | warning | `backgroundColor`/`foregroundColor` pairs below WCAG AA (4.5:1) — checked in **both** light and dark resolutions |
| `missing-dark-value` | warning | A custom color has a light value but no `dark` value, with `appearance: [light, dark]` declared |
| `non-point-unit` | warning | A dimension uses `px`/`rem`/`em` instead of `pt` |
| `dynamic-type-missing` | info | A typography level has a fixed `fontSize` but no `textStyle` (won't scale with accessibility settings) |
| `orphaned-tokens` | warning | Color tokens defined but never referenced by any component |
| `section-order` | warning | Sections out of canonical order |
| `unknown-key` | warning | Top-level YAML key looks like a typo of a known key; custom extension keys stay silent |

Duplicate section headings are an error; unknown sections, unknown token names, and unknown component properties are preserved/accepted (with a warning for unknown component properties), exactly as in the base spec.

## Philosophy (unchanged)

The reasons this format works are platform-independent, and they apply with full force on Apple platforms.

**Prose, not tokens, is the focus.** Token values are *context*, not rendering instructions. We do not reinvent the decades of work in UIKit, SwiftUI, SF Pro, and the HIG; we point the agent at them. The `Theme.swift` is downstream of the prose.

**A specific reference carries more than a list of adjectives.** "Feels like Apple Notes, but for field biologists" tells the agent about the navigation, the grouped lists, the restraint, the single accent, and the Dynamic Type discipline — all at once. "Modern, clean, premium" tells it to render the average of everything.

**Negative constraints define the character.** Naming the reference imports its restrictions for free: a System app *does not* use custom fonts for body text, *does not* shadow its list rows, *does not* fight the back-swipe. An intentional, short "Don'ts" list sharpens this; a long rambling one is a sign the reference was too vague.

**The format grows through its users, not its spec.** Beyond the standardized minimum (name, colors, typography, spacing, rounded, components), define whatever your system needs — the linter accepts any key and the agent reads any prose:

````md
## SF Symbols

```yaml
symbols:
  weight: semibold
  rendering: hierarchical   # monochrome | hierarchical | palette | multicolor
  scale: medium
```

Symbols are rendered `hierarchical` so a single accent color carries depth.
Never mix rendering modes within one screen. Prefer system symbols; only
introduce a custom symbol when no system one fits, and match its optical
weight to the surrounding text.

## Haptics

```yaml
haptics:
  selection: selection      # UISelectionFeedbackGenerator
  success: notificationSuccess
  impact: light
```

Haptics confirm, they don't decorate. Selection feedback on segmented
changes; a single success notification on commit; light impact on a primary
button. Never chain haptics or fire one on scroll.

## Motion

```yaml
motion:
  feedback: spring(response: 0.3, dampingFraction: 0.85)
  content: easeInOut(0.25)
```

Transitions are quick and native. Interactive feedback uses the spring;
content transitions use `easeInOut`. Respect Reduce Motion — collapse springs
to a cross-dissolve when it's enabled.
````

No spec change was needed for any of these, because the tokens are context and the agent reads the prose.

## Status

This Apple/SwiftUI edition tracks DESIGN.md at version `alpha`. The token schema and section model mirror the upstream spec; the Apple-specific additions (`platform`, `materials`, adaptive colors, `textStyle`, `fontDesign`, `curve`, the Apple component properties, and the Swift export targets) are this edition's extensions and may evolve as the upstream format matures.

## Attribution

Adapted from [DESIGN.md](https://github.com/google-labs-code/design.md) by Google Labs. The format concept, section model, `{path.to.token}` reference syntax, and prose-first philosophy are theirs; this document re-expresses them for UIKit and SwiftUI.
