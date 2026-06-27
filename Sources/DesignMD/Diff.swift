// Token diff engine. Mirrors `diffMaps` (utils.ts) and `commands/diff.ts`.

public struct MapDiff: Equatable, Sendable {
    public var added: [String]
    public var removed: [String]
    public var modified: [String]
}

/// Diff two ordered maps — added/removed/modified keys. Modified uses value
/// equality (the Swift analogue of the upstream JSON.stringify comparison).
public func diffMaps<V: Equatable>(_ before: OrderedDict<V>, _ after: OrderedDict<V>) -> MapDiff {
    var added: [String] = []
    var removed: [String] = []
    var modified: [String] = []
    for key in after.keys {
        if !before.has(key) {
            added.append(key)
        } else if before.get(key) != after.get(key) {
            modified.append(key)
        }
    }
    for key in before.keys where !after.has(key) {
        removed.append(key)
    }
    return MapDiff(added: added, removed: removed, modified: modified)
}

public struct DiffReport {
    public struct Tokens {
        public var colors: MapDiff
        public var typography: MapDiff
        public var rounded: MapDiff
        public var spacing: MapDiff
        public var components: MapDiff
    }
    public struct Findings {
        public var before: LintSummary
        public var after: LintSummary
        public var deltaErrors: Int
        public var deltaWarnings: Int
    }
    public var tokens: Tokens
    public var findings: Findings
    public var regression: Bool
}

/// Compare two DESIGN.md documents and report token-level + finding changes.
public func computeDiff(before beforeContent: String, after afterContent: String) -> DiffReport {
    let beforeReport = lint(beforeContent)
    let afterReport = lint(afterContent)

    func props(_ comps: OrderedDict<ComponentDef>) -> OrderedDict<OrderedDict<ResolvedValue>> {
        var out = OrderedDict<OrderedDict<ResolvedValue>>()
        for (name, comp) in comps { out.set(name, comp.properties) }
        return out
    }

    let tokens = DiffReport.Tokens(
        colors: diffMaps(beforeReport.designSystem.colors, afterReport.designSystem.colors),
        typography: diffMaps(beforeReport.designSystem.typography, afterReport.designSystem.typography),
        rounded: diffMaps(beforeReport.designSystem.rounded, afterReport.designSystem.rounded),
        spacing: diffMaps(beforeReport.designSystem.spacing, afterReport.designSystem.spacing),
        components: diffMaps(props(beforeReport.designSystem.components), props(afterReport.designSystem.components)))

    let regression = afterReport.summary.errors > beforeReport.summary.errors
        || afterReport.summary.warnings > beforeReport.summary.warnings

    return DiffReport(
        tokens: tokens,
        findings: DiffReport.Findings(
            before: beforeReport.summary,
            after: afterReport.summary,
            deltaErrors: afterReport.summary.errors - beforeReport.summary.errors,
            deltaWarnings: afterReport.summary.warnings - beforeReport.summary.warnings),
        regression: regression)
}
