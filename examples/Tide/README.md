# Tide — worked example

An end-to-end example of the `designmd` workflow for an Apple app.

| File | What it is |
|------|------------|
| `DESIGN.md` | The **source of truth** — design tokens (YAML) + prose. Edit this. |
| `Theme.swift` | **Generated** from `DESIGN.md`. A strongly-typed `Theme` enum (`Theme.Colors.accent`, `Theme.Spacing.md`, …). Do not edit by hand. |
| `Tide.xcassets/` | **Generated** Asset Catalog — one `.colorset` per color token, so `Color("accent")` resolves at runtime. |
| `TideCardView.swift` | A hand-written SwiftUI view that *consumes* `Theme`. Every value traces back to a token in `DESIGN.md`. |

## The loop

```bash
# 1. Validate (use in CI — fails on contrast/missing-primary/broken-ref/…)
designmd lint DESIGN.md

# 2. Regenerate the native theme whenever DESIGN.md changes
designmd export DESIGN.md --format swift --out Theme.swift
designmd export DESIGN.md --format asset-catalog --out Tide.xcassets

# 3. (optional) Catch design regressions between versions
designmd diff DESIGN.md DESIGN-v2.md
```

Then drop `Theme.swift` + `Tide.xcassets` into an Xcode app and use them
(see `TideCardView.swift`). Change a color in `DESIGN.md`, rerun step 2, and the
whole UI follows — no hand-syncing of hex values.

`Theme.swift` + `TideCardView.swift` type-check together against SwiftUI
(verified: `swiftc -typecheck Theme.swift TideCardView.swift`).
