# designmd-swift

**English** · [繁體中文](README.zh-TW.md)

[![CI](https://github.com/wei18/designmd-swift/actions/workflows/design-lint.yml/badge.svg)](https://github.com/wei18/designmd-swift/actions/workflows/design-lint.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg)](#)

A Swift port of [`@google/design.md`](https://github.com/google-labs-code/design.md) —
a linter, differ, and exporter for the **DESIGN.md** format: the machine-readable +
prose design-system spec that coding agents read. This edition is built for the
**UIKit / SwiftUI development workflow**: lint a `DESIGN.md` in CI, diff it for
regressions, and generate a native `Theme.swift` + Asset Catalog instead of Tailwind.

Pure Swift + Foundation — builds and runs on **macOS and Linux**. No SwiftUI/UIKit
dependency: the tool *emits* Apple artifacts as text, it doesn't link UI frameworks.

## What is DESIGN.md?

A single file that pairs **machine-readable design tokens** (YAML front matter) with
**human-readable rationale** (markdown prose). Tokens give agents exact values; prose
tells them *why*. It's the persistent, structured source of truth that keeps
agent-generated UI consistent across screens and sessions.

```markdown
---
name: Tide
colors:
  primary:   "#0B3D52"
  accent:    "#00A0C6"
typography:
  largeTitle: { fontFamily: SF Pro, fontSize: 34pt, fontWeight: "700" }
rounded:
  md: 12pt
---

## Overview
A calm tide tracker that should feel like a first-party Apple app.
```

## Why use it in an Apple project

The value is at **dev time / agent time**, not app runtime:

- **Consistency** — give an AI agent one structured design system so generated SwiftUI
  doesn't drift screen-to-screen.
- **Single source of truth** — `export` regenerates a typed `Theme.swift` + Asset
  Catalog; no hand-syncing scattered `Color(hex:)` / `.padding(16)`.
- **CI guardrails** — `lint` fails the build on WCAG contrast violations, missing
  `primary`, broken references, etc. `diff` catches design regressions between versions.

## Install & build

```bash
git clone https://github.com/wei18/designmd-swift.git
cd designmd-swift
swift build -c release   # binary at .build/release/designmd
swift test               # 25 tests
```

## CLI

```bash
designmd lint DESIGN.md                 # JSON findings + summary; exit 1 on errors
designmd lint DESIGN.md --format markdown
cat DESIGN.md | designmd lint -         # stdin
designmd diff OLD.md NEW.md             # token + finding diff; exit 1 on regression

# Export — Apple-native targets replace Tailwind; DTCG kept for interop
designmd export DESIGN.md --format dtcg                          # W3C tokens.json → stdout
designmd export DESIGN.md --format swift  --out Theme.swift      # SwiftUI theme
designmd export DESIGN.md --format asset-catalog --out Colors.xcassets

# Spec — handy for injecting format context into agent prompts
designmd spec --rules

# Fix — reorder sections into the canonical order
designmd fix DESIGN.md            # fixed content → stdout
designmd fix DESIGN.md --write    # rewrite in place
designmd fix DESIGN.md --format json   # { details: { beforeOrder, afterOrder }, fixedContent }
```

`swift` emits a strongly-typed `Theme` enum (`Theme.Colors.primary`, `Theme.Spacing.md`,
`Theme.Typography.body`, `Theme.Radius.lg`) — colors as sRGB `Color` literals, dimensions
as `CGFloat` points, typography as `Font` (SF Mono → `.monospaced`, New York → `.serif`,
SF Pro Rounded → `.rounded`; other families → `Font.custom`). `asset-catalog` writes one
`.colorset` per color token so `Color("on-surface")` resolves at runtime.

## Library

```swift
import DesignMD

let report = lint(markdownString)
report.findings      // [Finding]
report.summary       // errors / warnings / infos
report.designSystem  // fully resolved model (colors, typography, …)

let d = computeDiff(before: oldString, after: newString)   // d.regression: Bool
let theme = exportSwiftTheme(report.designSystem)          // Theme.swift source
let dtcg  = exportDTCG(report.designSystem).serialize()    // W3C tokens.json
```

## Example

[`examples/Tide`](examples/Tide) is a complete, compilable walkthrough: a `DESIGN.md`,
the generated `Theme.swift` + `Tide.xcassets`, a SwiftUI `TideCardView` that consumes
them, and a self-contained [`prototype.html`](examples/Tide/prototype.html) visualizing
the tokens and the lint results (it even catches a real WCAG failure — white-on-accent at
3.07:1).

## CI

[`.github/workflows/design-lint.yml`](.github/workflows/design-lint.yml) builds the tool,
runs the tests, then gates the build on `designmd lint` over every `DESIGN.md` in the repo
(inline `::error file=…::` annotations). Runs on the `swift:6.0` Linux container with
SwiftPM build caching. Point it at specific files via the `DESIGN_FILES` env.

## Parity with upstream

The parser, model, CSS color science (WCAG luminance/contrast), `{path.to.token}`
resolution (with cycle + depth guards), all nine lint rules, the diff engine, the DTCG
exporter, and the `spec` command are faithful ports. Verified **byte-identical** against
the upstream TypeScript CLI: `lint` (12 fixtures), `diff` (5 pairs),
`export --format dtcg` (7 fixtures), and `spec` (rules table + rules JSON). 25 tests.

### One intentional deviation: `pt` units

Upstream accepts only `px`/`rem`/`em` and flags everything else. This edition adds **`pt`
(points)** as a first-class standard unit so UIKit/SwiftUI design systems aren't wrongly
flagged. `px`/`rem`/`em` remain accepted. See `SpecConfig.standardUnits`.

## Commands

| Command | Purpose |
|---------|---------|
| `lint`  | Validate structure, references, WCAG contrast (9 rules); exit 1 on errors |
| `diff`  | Token + finding diff between two versions; exit 1 on regression |
| `export`| `dtcg` (W3C tokens.json) · `swift` (Theme.swift) · `asset-catalog` (.xcassets) |
| `spec`  | Emit the format spec + active rules table (markdown or json) |
| `fix`   | Reorder sections into the canonical order (`--write` in place) |

## License & attribution

Apache-2.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)). Ported from
[DESIGN.md](https://github.com/google-labs-code/design.md) by Google Labs; the format,
spec model, `{path.to.token}` syntax, lint semantics, and prose-first philosophy are
theirs, reimplemented here in Swift for Apple platforms.
