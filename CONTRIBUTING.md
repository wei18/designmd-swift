# Contributing

Thanks for your interest in `designmd-swift`.

## Development

```bash
swift build          # build the library + `designmd` CLI
swift test           # run the test suite (32 tests)
swift run designmd lint examples/Tide/DESIGN.md
```

Requires Swift 5.9+. The package is pure Swift + Foundation and builds on macOS
and Linux (CI runs on the `swift:6.0` Linux container).

## Project layout

- `Sources/DesignMD/` — the library: parser, model, color science, lint rules,
  diff, exporters (`Export/`), and the bundled spec (`Resources/`).
- `Sources/CLI/` — the `designmd` executable (ArgumentParser).
- `Tests/DesignMDTests/` — unit tests + golden-parity fixtures.
- `examples/Tide/` — a worked end-to-end example.
- `docs/` — the Apple/SwiftUI format notes.

## Parity with upstream

This is a port of [google-labs-code/design.md](https://github.com/google-labs-code/design.md).
The parser, model, lint rules, diff, and DTCG export are intended to stay
**byte-faithful** to the upstream TypeScript CLI. If you change any of those,
add or update a golden fixture under `Tests/DesignMDTests/Fixtures/` and keep the
parity tests green.

Intentional, documented deviations (do not "fix" these toward upstream without
discussion): `pt` is an accepted unit; the Tailwind exporters are replaced by
the SwiftUI / Asset-Catalog exporters; a few upstream parser bugs (e.g. CRLF
handling) are deliberately not reproduced. See `NOTICE` and the README.

## Pull requests

- Keep changes surgical and matched to the surrounding style.
- Run `swift test` before opening a PR; CI must be green.
- For new lint behavior, include a fixture demonstrating it.

## License

By contributing you agree your contributions are licensed under the
Apache License, Version 2.0 (see `LICENSE`).
