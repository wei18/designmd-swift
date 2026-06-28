# Examples

Worked, end-to-end examples of the `designmd` workflow:
`DESIGN.md` → `designmd lint` → `designmd export` → SwiftUI.

| Example | What it shows |
|---------|---------------|
| [`Tide`](Tide) | A small, hand-authored Apple design system (`pt` units), a generated `Theme.swift` + Asset Catalog, a SwiftUI `TideCardView` that consumes them, and a [visual `prototype.html`](Tide/prototype.html) that also surfaces a real WCAG contrast failure caught by the linter. |
| [`AtmosphericGlass`](AtmosphericGlass) | A large real-world system (45 colors, full type scale) adapted from upstream — shows the tool on a non-trivial input; the generated `Theme.swift` type-checks against SwiftUI. |

Regenerate any example's artifacts after editing its `DESIGN.md`:

```bash
designmd export <dir>/DESIGN.md --format swift --out <dir>/Theme.swift
designmd export <dir>/DESIGN.md --format asset-catalog --out <dir>/<Name>.xcassets
```
