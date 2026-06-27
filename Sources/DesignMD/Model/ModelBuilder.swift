// Model builder — resolves parsed YAML into a typed DesignSystemState.
// Faithful port of `model/handler.ts`.

import Foundation

public struct ModelResult {
    public var designSystem: DesignSystemState
    public var findings: [Finding]
}

/// Reference box for findings — avoids `inout` aliasing inside leaf closures.
final class FindingsBox {
    var list: [Finding] = []
    func append(_ f: Finding) { list.append(f) }
}

/// Allowed-unit message fragment, sourced from SpecConfig (pt-aware).
private let allowedUnitsList: String = {
    // "pt, px, rem, and em"
    let units = SpecConfig.standardUnits
    if units.count <= 1 { return units.joined() }
    return units.dropLast().joined(separator: ", ") + ", and " + units.last!
}()

public func buildModel(_ input: ParsedDesignSystem) -> ModelResult {
    let findings = FindingsBox()
    var symbolTable = OrderedDict<ResolvedValue>()
    var colors = OrderedDict<ResolvedColor>()
    var typography = OrderedDict<ResolvedTypography>()
    var rounded = OrderedDict<ResolvedDimension>()
    var spacing = OrderedDict<ResolvedDimension>()

    // ── Phase 1: primitive tokens ──────────────────────────────────

    // Colors
    if let colorsValue = input.colors {
        forEachLeaf(colorsValue, rootPath: "colors", findings: findings) { name, raw in
            let key = "colors.\(name)"
            if case let .string(s) = raw, isTokenReference(s) {
                symbolTable.set(key, .string(s))
            } else if case let .string(s) = raw, isValidColor(s) {
                let resolved = parseColorOrNil(s)!
                colors.set(name, resolved)
                symbolTable.set(key, .color(resolved))
            } else {
                findings.append(Finding(
                    severity: .error, path: key,
                    message: "'\(raw.display)' is not a valid color. Expected a CSS color value (e.g., #ffffff, rgb(0 0 0), oklch(0.5 0.2 240))."))
                symbolTable.set(key, scalarToResolved(raw))
            }
        }
    }

    // Typography
    if let typographyValue = input.typography, let entries = typographyValue.entries {
        for entry in entries {
            let resolved = parseTypography(entry.value, path: "typography.\(entry.key)", findings: findings)
            typography.set(entry.key, resolved)
            symbolTable.set("typography.\(entry.key)", .typography(resolved))
        }
    }

    // Rounded
    if let roundedValue = input.rounded {
        forEachLeaf(roundedValue, rootPath: "rounded", findings: findings) { name, raw in
            let key = "rounded.\(name)"
            guard case let .string(s) = raw else { return }
            if Dimensions.isParseable(s) {
                let resolved = parseDimension(s)
                if !Dimensions.standardUnits.contains(resolved.unit) {
                    findings.append(Finding(
                        severity: .error, path: key,
                        message: "'\(s)' has an invalid unit '\(resolved.unit)'. Only \(allowedUnitsList) are allowed."))
                }
                rounded.set(name, resolved)
                symbolTable.set(key, .dimension(resolved))
            } else if !isTokenReference(s) {
                findings.append(Finding(
                    severity: .error, path: key,
                    message: "'\(s)' is not a valid dimension."))
                symbolTable.set(key, .string(s))
            } else {
                symbolTable.set(key, .string(s))
            }
        }
    }

    // Spacing
    if let spacingValue = input.spacing {
        forEachLeaf(spacingValue, rootPath: "spacing", findings: findings) { name, raw in
            let key = "spacing.\(name)"
            if case let .string(s) = raw, Dimensions.isParseable(s) {
                let resolved = parseDimension(s)
                spacing.set(name, resolved)
                symbolTable.set(key, .dimension(resolved))
            } else {
                symbolTable.set(key, scalarToResolved(raw))
            }
        }
    }

    // ── Phase 2: chained references ────────────────────────────────
    if let colorsValue = input.colors {
        forEachLeaf(colorsValue) { name, raw in
            guard case let .string(s) = raw, isTokenReference(s) else { return }
            var visited = Set<String>()
            if let resolved = resolveReference(symbolTable, String(s.dropFirst().dropLast()), &visited),
               case let .color(c) = resolved {
                colors.set(name, c)
                symbolTable.set("colors.\(name)", .color(c))
            }
        }
    }
    if let roundedValue = input.rounded {
        forEachLeaf(roundedValue) { name, raw in
            guard case let .string(s) = raw, isTokenReference(s) else { return }
            var visited = Set<String>()
            if let resolved = resolveReference(symbolTable, String(s.dropFirst().dropLast()), &visited),
               case let .dimension(d) = resolved {
                rounded.set(name, d)
                symbolTable.set("rounded.\(name)", .dimension(d))
            }
        }
    }
    if let spacingValue = input.spacing {
        forEachLeaf(spacingValue) { name, raw in
            guard case let .string(s) = raw, isTokenReference(s) else { return }
            var visited = Set<String>()
            if let resolved = resolveReference(symbolTable, String(s.dropFirst().dropLast()), &visited),
               case let .dimension(d) = resolved {
                spacing.set(name, d)
                symbolTable.set("spacing.\(name)", .dimension(d))
            }
        }
    }

    // ── Phase 3: components ────────────────────────────────────────
    var components = OrderedDict<ComponentDef>()
    if let componentsValue = input.components, let compEntries = componentsValue.entries {
        for comp in compEntries {
            var properties = OrderedDict<ResolvedValue>()
            var unresolvedRefs: [String] = []
            for prop in (comp.value.entries ?? []) {
                let propName = prop.key
                switch prop.value {
                case let .number(n):
                    properties.set(propName, .number(n))
                case let .bool(b):
                    properties.set(propName, .bool(b))
                case let .string(s):
                    if isTokenReference(s) {
                        var visited = Set<String>()
                        if let resolved = resolveReference(symbolTable, String(s.dropFirst().dropLast()), &visited) {
                            properties.set(propName, resolved)
                        } else {
                            unresolvedRefs.append(s)
                            properties.set(propName, .string(s))
                        }
                    } else if isValidColor(s) {
                        properties.set(propName, .color(parseColorOrNil(s)!))
                    } else if Dimensions.isParseable(s) {
                        properties.set(propName, .dimension(parseDimension(s)))
                    } else {
                        properties.set(propName, .string(s))
                    }
                default:
                    properties.set(propName, .string(prop.value.display))
                }
            }
            components.set(comp.key, ComponentDef(properties: properties, unresolvedRefs: unresolvedRefs))
        }
    }

    let schemaSet = Set(SpecConfig.schemaKeys)
    let unknownKeys = input.topLevelKeys.filter { !schemaSet.contains($0) }
    var unknownKeyValues: [String: YAMLValue] = [:]
    for key in unknownKeys {
        if let v = input.rawValues[key] { unknownKeyValues[key] = v }
    }

    var state = DesignSystemState()
    state.name = input.name
    state.description = input.description
    state.colors = colors
    state.typography = typography
    state.rounded = rounded
    state.spacing = spacing
    state.components = components
    state.symbolTable = symbolTable
    state.sections = input.sections
    state.unknownKeys = unknownKeys
    state.unknownKeyValues = unknownKeyValues

    return ModelResult(designSystem: state, findings: findings.list)
}

// ── Pure helpers ───────────────────────────────────────────────────

func parseColorOrNil(_ raw: String) -> ResolvedColor? { parseCssColor(raw) }

private func parseDimension(_ raw: String) -> ResolvedDimension {
    let parts = Dimensions.parseParts(raw)!
    return ResolvedDimension(value: parts.value, unit: parts.unit)
}

private func scalarToResolved(_ v: YAMLValue) -> ResolvedValue {
    switch v {
    case let .string(s): return .string(s)
    case let .number(n): return .number(n)
    case let .bool(b): return .bool(b)
    case .null: return .string("null")
    case .array, .mapping: return .string(v.display)
    }
}

private func parseTypography(_ props: YAMLValue, path: String, findings: FindingsBox) -> ResolvedTypography {
    var result = ResolvedTypography()
    let entries = props.entries ?? []
    func prop(_ name: String) -> YAMLValue? { entries.first(where: { $0.key == name })?.value }

    if case let .string(ff)? = prop("fontFamily") {
        if isValidColor(ff) {
            findings.append(Finding(
                severity: .error, path: "\(path).fontFamily",
                message: "'\(ff)' appears to be a color, not a valid font family."))
        }
        result.fontFamily = ff
    }

    if let fw = prop("fontWeight") {
        var fwValue: Double?
        switch fw {
        case let .number(n): fwValue = n
        case let .string(s): if let d = Double(s) { fwValue = d }
        default: break
        }
        if let fwValue {
            result.fontWeight = fwValue
        } else {
            findings.append(Finding(
                severity: .error, path: "\(path).fontWeight",
                message: "'\(fw.display)' is not a valid font weight. Expected a number."))
        }
    }

    if case let .string(s)? = prop("fontFeature") { result.fontFeature = s }
    if case let .string(s)? = prop("fontVariation") { result.fontVariation = s }

    for name in ["fontSize", "lineHeight", "letterSpacing"] {
        guard case let .string(raw)? = prop(name) else { continue }
        if Dimensions.isParseable(raw) {
            let parsed = parseDimension(raw)
            if !Dimensions.standardUnits.contains(parsed.unit) {
                findings.append(Finding(
                    severity: .error, path: "\(path).\(name)",
                    message: "'\(raw)' has an invalid unit '\(parsed.unit)'. Only \(allowedUnitsList) are allowed."))
            }
            assign(&result, name, parsed)
        } else if name == "lineHeight", isUnitlessNumber(raw) {
            assign(&result, name, ResolvedDimension(value: jsParseFloat(raw), unit: ""))
        } else if !isTokenReference(raw) {
            findings.append(Finding(
                severity: .error, path: "\(path).\(name)",
                message: "'\(raw)' is not a valid dimension."))
        }
    }
    return result
}

private func assign(_ t: inout ResolvedTypography, _ name: String, _ dim: ResolvedDimension) {
    switch name {
    case "fontSize": t.fontSize = dim
    case "lineHeight": t.lineHeight = dim
    case "letterSpacing": t.letterSpacing = dim
    default: break
    }
}

/// Matches the TS `/^\d*\.?\d+$/` check used for unitless lineHeight.
private func isUnitlessNumber(_ s: String) -> Bool {
    guard !s.isEmpty else { return false }
    var sawDigit = false
    var sawDot = false
    for c in s {
        if c.isNumber && c.isASCII { sawDigit = true }
        else if c == "." && !sawDot { sawDot = true }
        else { return false }
    }
    return sawDigit
}

/// Resolve a token reference with chained resolution and cycle detection.
func resolveReference(_ symbolTable: OrderedDict<ResolvedValue>, _ path: String,
                      _ visited: inout Set<String>, _ depth: Int = 0) -> ResolvedValue? {
    if depth > SpecConfig.maxReferenceDepth { return nil }
    if visited.contains(path) { return nil }
    visited.insert(path)
    guard let value = symbolTable.get(path) else { return nil }
    if case let .string(s) = value, isTokenReference(s) {
        return resolveReference(symbolTable, String(s.dropFirst().dropLast()), &visited, depth + 1)
    }
    return value
}

/// WCAG 2.1 contrast ratio between two resolved colors.
public func contrastRatio(_ a: ResolvedColor, _ b: ResolvedColor) -> Double {
    let l1 = max(a.luminance, b.luminance)
    let l2 = min(a.luminance, b.luminance)
    return (l1 + 0.05) / (l2 + 0.05)
}

/// Recursively iterate leaf nodes of a YAML mapping. Mappings recurse; all
/// other values (scalars, arrays) are leaves. Dotted paths (e.g. "background.light").
func forEachLeaf(_ obj: YAMLValue, prefix: String = "", depth: Int = 0,
                 rootPath: String? = nil, findings: FindingsBox,
                 _ fn: (String, YAMLValue) -> Void) {
    if depth > SpecConfig.maxTokenNestingDepth {
        if let rootPath {
            let already = findings.list.contains { $0.path == rootPath && $0.message.contains("nesting depth") }
            if !already {
                findings.append(Finding(
                    severity: .error, path: rootPath,
                    message: "Token nesting depth exceeds maximum allowed depth of \(SpecConfig.maxTokenNestingDepth)."))
            }
        }
        return
    }
    guard case let .mapping(entries) = obj else { return }
    for entry in entries {
        let full = prefix.isEmpty ? entry.key : "\(prefix).\(entry.key)"
        if entry.value.isObject {
            forEachLeaf(entry.value, prefix: full, depth: depth + 1, rootPath: rootPath, findings: findings, fn)
        } else {
            fn(full, entry.value)
        }
    }
}

/// Overload without findings (Phase 2 chained resolution doesn't emit findings).
func forEachLeaf(_ obj: YAMLValue, prefix: String = "", _ fn: (String, YAMLValue) -> Void) {
    forEachLeaf(obj, prefix: prefix, depth: 0, rootPath: nil, findings: FindingsBox(), fn)
}
