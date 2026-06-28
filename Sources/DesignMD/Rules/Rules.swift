// The ten default lint rules. Faithful ports of `linter/rules/*.ts`.

import Foundation

private func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n != 1 ? "s" : "")" }

// ── broken-ref ─────────────────────────────────────────────────────
func brokenRef(_ state: DesignSystemState) -> [RuleFinding] {
    var findings: [RuleFinding] = []
    for (compName, comp) in state.components {
        for ref in comp.unresolvedRefs {
            findings.append(RuleFinding(
                path: "components.\(compName)",
                message: "Reference \(ref) does not resolve to any defined token."))
        }
        for (propName, _) in comp.properties {
            if !SpecConfig.validComponentSubTokens.contains(propName) {
                findings.append(RuleFinding(
                    path: "components.\(compName).\(propName)",
                    message: "'\(propName)' is not a recognized component sub-token. Valid sub-tokens: \(SpecConfig.validComponentSubTokens.joined(separator: ", ")).",
                    severity: .warning))
            }
        }
    }
    return findings
}

// ── missing-primary ────────────────────────────────────────────────
func missingPrimary(_ state: DesignSystemState) -> [RuleFinding] {
    if state.colors.size > 0 && !state.colors.has("primary") {
        return [RuleFinding(path: "colors",
            message: "No 'primary' color defined. The agent will auto-generate key colors, reducing your control over the palette.")]
    }
    return []
}

// ── contrast-ratio ─────────────────────────────────────────────────
private let wcagAAMinimum = 4.5
func contrastCheck(_ state: DesignSystemState) -> [RuleFinding] {
    var findings: [RuleFinding] = []
    for (compName, comp) in state.components {
        guard let bgValue = comp.properties.get("backgroundColor"),
              let textValue = comp.properties.get("textColor"),
              let bgColor = bgValue.asColor,
              let textColor = textValue.asColor else { continue }
        let ratio = contrastRatio(bgColor, textColor)
        if ratio < wcagAAMinimum {
            findings.append(RuleFinding(
                path: "components.\(compName)",
                message: "textColor (\(textColor.hex)) on backgroundColor (\(bgColor.hex)) has contrast ratio \(String(format: "%.2f", ratio)):1, below WCAG AA minimum of 4.5:1."))
        }
    }
    return findings
}

// ── orphaned-tokens ────────────────────────────────────────────────
private let md3StandardFamilies: Set<String> = [
    "primary", "secondary", "tertiary", "error", "surface", "background", "outline",
]

private func colorFamily(_ name: String) -> String {
    var n = name
    if n.hasPrefix("on-") { n = String(n.dropFirst(3)) }
    if n.hasPrefix("inverse-") { n = String(n.dropFirst(8)) }
    if n.hasPrefix("on-") { n = String(n.dropFirst(3)) }
    if let r = n.range(of: "-container") { n = String(n[n.startIndex..<r.lowerBound]) }
    if let r = n.range(of: "-fixed") { n = String(n[n.startIndex..<r.lowerBound]) }
    for suffix in ["-dim", "-bright", "-tint", "-variant"] where n.hasSuffix(suffix) {
        n = String(n.dropLast(suffix.count)); break
    }
    return n
}

func orphanedTokens(_ state: DesignSystemState) -> [RuleFinding] {
    if state.components.size == 0 { return [] }

    // Referenced-by-path (computed during model resolution) — the value-typed
    // analogue of upstream's reference-identity scan. Avoids the false
    // suppression that value-equality caused for distinct tokens of equal value.
    let referencedPaths = state.referencedTokenPaths

    var referencedFamilies = Set<String>()
    for path in referencedPaths where path.hasPrefix("colors.") {
        referencedFamilies.insert(colorFamily(String(path.dropFirst("colors.".count))))
    }

    var findings: [RuleFinding] = []
    for (name, _) in state.colors {
        let path = "colors.\(name)"
        if referencedPaths.contains(path) { continue }
        let family = colorFamily(name)
        if referencedFamilies.contains(family) { continue }
        if md3StandardFamilies.contains(family) { continue }
        findings.append(RuleFinding(path: path,
            message: "'\(name)' is defined but never referenced by any component."))
    }
    return findings
}

// ── token-summary ──────────────────────────────────────────────────
func tokenSummary(_ state: DesignSystemState) -> [RuleFinding] {
    var parts: [String] = []
    if state.colors.size > 0 { parts.append(plural(state.colors.size, "color")) }
    if state.typography.size > 0 { parts.append(plural(state.typography.size, "typography scale")) }
    if state.rounded.size > 0 { parts.append(plural(state.rounded.size, "rounding level")) }
    if state.spacing.size > 0 { parts.append(plural(state.spacing.size, "spacing token")) }
    if state.components.size > 0 { parts.append(plural(state.components.size, "component")) }
    if !parts.isEmpty {
        return [RuleFinding(message: "Design system defines \(parts.joined(separator: ", ")).")]
    }
    return []
}

// ── missing-sections ───────────────────────────────────────────────
func missingSections(_ state: DesignSystemState) -> [RuleFinding] {
    var findings: [RuleFinding] = []
    let checks: [(map: OrderedDict<ResolvedDimension>, name: String, fallback: String)] = [
        (state.spacing, "spacing", "Layout spacing will fall back to agent defaults."),
        (state.rounded, "rounded", "Corner rounding will fall back to agent defaults."),
    ]
    for c in checks where c.map.size == 0 && state.colors.size > 0 {
        findings.append(RuleFinding(path: c.name, message: "No '\(c.name)' section defined. \(c.fallback)"))
    }
    return findings
}

// ── missing-typography ─────────────────────────────────────────────
func missingTypography(_ state: DesignSystemState) -> [RuleFinding] {
    if state.typography.size == 0 && state.colors.size > 0 {
        return [RuleFinding(path: "typography",
            message: "No typography tokens defined. Agents will use default font choices, reducing your control over the design system's typographic identity.")]
    }
    return []
}

// ── section-order ──────────────────────────────────────────────────
private let orderMap: [String: Int] = {
    var m: [String: Int] = [:]
    for (i, s) in SpecConfig.canonicalOrder.enumerated() { m[s] = i }
    return m
}()

func sectionOrder(_ state: DesignSystemState) -> [RuleFinding] {
    let sections = state.sections ?? []
    if sections.isEmpty { return [] }
    let known = sections.map { SpecConfig.resolveAlias($0) }.filter { orderMap[$0] != nil }
    guard known.count >= 2 else { return [] }
    for i in 0..<(known.count - 1) {
        guard let cur = orderMap[known[i]], let next = orderMap[known[i + 1]] else { continue }
        if cur > next {
            return [RuleFinding(
                message: "Section '\(known[i])' appears before '\(known[i + 1])', which is out of order. Expected order: \(SpecConfig.canonicalOrder.joined(separator: ", "))")]
        }
    }
    return []
}

// ── unknown-key ────────────────────────────────────────────────────
private let maxTypoDistance = 2
func unknownKey(_ state: DesignSystemState) -> [RuleFinding] {
    let knownSet = Set(SpecConfig.schemaKeys)
    var findings: [RuleFinding] = []
    for key in (state.unknownKeys ?? []) {
        if knownSet.contains(key) { continue }
        var bestMatch: String?
        var bestDist = Int.max
        for known in SpecConfig.schemaKeys {
            let dist = levenshtein(key.lowercased(), known.lowercased())
            if dist < bestDist { bestDist = dist; bestMatch = known }
        }
        if bestDist <= maxTypoDistance, let bestMatch {
            findings.append(RuleFinding(path: key, message: "Unknown key \"\(key)\" — did you mean \"\(bestMatch)\"?"))
        }
    }
    return findings
}

// ── token-like-ignored ─────────────────────────────────────────────
private let tokenLikeTypographyProps: Set<String> = [
    "fontFamily", "fontSize", "fontWeight", "lineHeight", "letterSpacing",
]

private func matchesHexColor(_ s: String) -> Bool {
    guard s.hasPrefix("#") else { return false }
    let body = s.dropFirst()
    let n = body.count
    guard n == 3 || n == 4 || n == 6 || n == 8 else { return false }
    return body.allSatisfy { $0.isHexDigit }
}

/// Matches the TS `CSS_DIMENSION_RE` (pattern only, any letter unit).
private func matchesCssDimensionPattern(_ s: String) -> Bool {
    Dimensions.parseParts(s) != nil
}

private func hasTokenLikeContent(_ obj: YAMLValue) -> Bool {
    for entry in (obj.entries ?? []) {
        if tokenLikeTypographyProps.contains(entry.key) { return true }
        switch entry.value {
        case let .string(v):
            if matchesHexColor(v) || matchesCssDimensionPattern(v) { return true }
        case .mapping:
            if hasTokenLikeContent(entry.value) { return true }
        default:
            break
        }
    }
    return false
}

private func isTokenLikeMap(_ value: YAMLValue?) -> Bool {
    guard let value, value.isObject else { return false }
    return hasTokenLikeContent(value)
}

func tokenLikeIgnored(_ state: DesignSystemState) -> [RuleFinding] {
    let unknownKeys = state.unknownKeys ?? []
    let unknownKeyValues = state.unknownKeyValues ?? [:]
    var findings: [RuleFinding] = []
    for key in unknownKeys where isTokenLikeMap(unknownKeyValues[key]) {
        findings.append(RuleFinding(
            path: key,
            message: "\"\(key)\" looks like a design-token map but is not a recognized schema key "
                + "(colors, typography, spacing, rounded, components). "
                + "It will be silently ignored by export commands. "
                + "Rename it to a supported key or move its values under a recognized section."))
    }
    return findings
}

// ── Default rule set (order matters) ───────────────────────────────
public let defaultRuleDescriptors: [RuleDescriptor] = [
    RuleDescriptor(name: "broken-ref", severity: .error,
        description: "Broken/circular references and unknown component sub-tokens.", run: brokenRef),
    RuleDescriptor(name: "missing-primary", severity: .warning,
        description: "Missing primary color — warns when colors are defined but no 'primary' exists.", run: missingPrimary),
    RuleDescriptor(name: "contrast-ratio", severity: .warning,
        description: "WCAG contrast ratio — warns when component backgroundColor/textColor pairs fall below the AA minimum of 4.5:1.", run: contrastCheck),
    RuleDescriptor(name: "orphaned-tokens", severity: .warning,
        description: "Orphaned tokens — tokens defined but never referenced by any component.", run: orphanedTokens),
    RuleDescriptor(name: "token-summary", severity: .info,
        description: "Token count summary — emits an info diagnostic summarizing how many tokens are defined.", run: tokenSummary),
    RuleDescriptor(name: "missing-sections", severity: .info,
        description: "Missing sections — notes when optional sections (spacing, rounded) are absent.", run: missingSections),
    RuleDescriptor(name: "missing-typography", severity: .warning,
        description: "Missing typography — warns when colors are defined but no typography tokens exist.", run: missingTypography),
    RuleDescriptor(name: "section-order", severity: .warning,
        description: "Section order — warns when sections are out of canonical order.", run: sectionOrder),
    RuleDescriptor(name: "unknown-key", severity: .warning,
        description: "Unknown key — warns when a top-level YAML key looks like a typo of a known schema key.", run: unknownKey),
    RuleDescriptor(name: "token-like-ignored", severity: .warning,
        description: "Warns when a top-level YAML key looks like a design-token map but is not part of the recognized export schema and will be silently ignored.", run: tokenLikeIgnored),
]
