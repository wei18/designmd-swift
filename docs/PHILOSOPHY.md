# Philosophy

DESIGN.md captures how a design looks, feels, and behaves. **The prose is where
the design lives.** Everything else — the tokens, this tool — exists to support
it. This document adapts the upstream
[PHILOSOPHY](https://github.com/google-labs-code/design.md/blob/main/PHILOSOPHY.md)
for Apple platforms; the ideas are theirs, the framing here is for UIKit/SwiftUI.

> The quality of a generated design is determined less by the precision of its
> values than by how clearly the intent is described.

## Prose, not tokens, is the focus

A `DESIGN.md` has two parts: tokens and prose. The tokens are *context*, not
rendering instructions — `designmd export` turns them into a `Theme.swift` or an
Asset Catalog, but the agent building your screens reads the prose to know how to
*apply* them.

```md
## Colors

The palette is a single ink over a warm neutral, plus one accent.
- **Ink** {colors.primary} carries all type; never pure black.
- **Accent** {colors.accent} is the *only* tint — `.tint(...)` on controls,
  never on a static label.
```

We don't reinvent the decades of work in UIKit, SwiftUI, SF Pro, Dynamic Type,
and the Human Interface Guidelines. We point the agent at them.

## A specific reference beats a list of adjectives

"Feels like Apple Notes, but for field biologists" evokes a whole world: the
grouped lists, the restraint, the single accent, the Dynamic Type discipline.
"Modern, clean, premium" evokes nothing specific — a model renders the average of
everything and the result is generic. Adjectives describe a region; a specific
reference describes a point.

## Negative constraints define the character

Naming a real reference imports its restrictions for free. A "System app" *does
not* use a custom font for body text, *does not* shadow its list rows, *does not*
fight the back-swipe — you don't have to enumerate these. A short, intentional
"Don'ts" list sharpens the reference; a long rambling one usually means the
reference was too vague to carry them.

## The format grows through its users

The spec standardizes a small universal core (name, colors, typography, spacing,
rounded, components). Everything beyond that is yours — `designmd` accepts any
key and the agent reads any prose. Apple systems often add sections the web never
needed:

````md
## SF Symbols
```yaml
symbols: { weight: semibold, rendering: hierarchical }
```
Symbols render hierarchical so one accent carries depth. Never mix rendering
modes within a screen.

## Haptics
```yaml
haptics: { selection: selection, success: notificationSuccess }
```
Haptics confirm, they don't decorate. Never chain them or fire on scroll.
````

No spec change is needed, because the tokens are context and the prose is the
design.
