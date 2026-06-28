# Atmospheric Glass — large real-world example

A dark, glassy design system with **45 color tokens**, a full type scale, and
component definitions. Adapted from the upstream
[`atmospheric-glass`](https://github.com/google-labs-code/design.md/tree/main/examples/atmospheric-glass)
example (Copyright 2026 Google LLC, Apache-2.0; see the repo `NOTICE`).

It demonstrates `designmd` on a non-trivial input:

```bash
designmd lint   DESIGN.md                                   # 0 errors, a few warnings
designmd export DESIGN.md --format swift --out Theme.swift  # 64 constants
designmd export DESIGN.md --format asset-catalog --out AtmosphericGlass.xcassets  # 47 .colorset
```

| File | What it is |
|------|------------|
| `DESIGN.md` | Source (upstream tokens; uses `px`/`rem`, which the tool accepts). |
| `Theme.swift` | Generated `Theme` enum — verified to type-check against SwiftUI. |
| `AtmosphericGlass.xcassets` | Generated Asset Catalog, one `.colorset` per color token. |

Note: this design predates the Apple edition, so it uses `px`/`rem` rather than
`pt`. The Swift exporter maps `px` straight to points and keeps `rem` values with
an inline note — see `Theme.swift`.
