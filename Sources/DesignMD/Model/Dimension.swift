// Dimension / reference validation helpers. Mirrors `model/spec.ts`.

import Foundation

public enum Dimensions {
    /// All known CSS length/percentage units (for generous parsing).
    /// Adding a new unit = one string here.
    static let cssUnits: Set<String> = [
        // Absolute
        "px", "cm", "mm", "in", "pt", "pc",
        // Relative to font
        "em", "rem", "ex", "ch", "cap", "ic", "lh", "rlh",
        // Viewport — classic
        "vh", "vw", "vmin", "vmax",
        // Viewport — dynamic/small/large
        "dvh", "dvw", "dvmin", "dvmax",
        "svh", "svw", "svmin", "svmax",
        "lvh", "lvw", "lvmin", "lvmax",
        // Container query units
        "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax",
        // Percentage
        "%",
    ]

    static let standardUnits = Set(SpecConfig.standardUnits)

    /// Parse a dimension string into numeric value and unit suffix.
    /// Equivalent to the regex `^(-?\d*\.?\d+)([a-zA-Z%]+)$`.
    /// Returns nil for non-dimension strings (bare numbers, keywords like `auto`).
    public static func parseParts(_ raw: String) -> (value: Double, unit: String)? {
        let chars = Array(raw)
        var i = 0
        let n = chars.count

        // Number part: -?\d*\.?\d+
        if i < n && chars[i] == "-" { i += 1 }
        let numStart = i
        while i < n && chars[i].isASCIIDigit { i += 1 }
        var sawFraction = false
        if i < n && chars[i] == "." {
            sawFraction = true
            i += 1
            let fracStart = i
            while i < n && chars[i].isASCIIDigit { i += 1 }
            if i == fracStart { return nil } // dot must be followed by digits
        }
        // Require at least one digit overall (the `\d+` at the end of the group).
        _ = sawFraction
        if i == numStart { return nil }

        let numberStr = String(chars[0..<i])
        let unitChars = chars[i...]
        guard !unitChars.isEmpty else { return nil }
        for c in unitChars where !(c.isASCIILetter || c == "%") { return nil }

        guard let value = Double(numberStr) else { return nil }
        return (value, String(unitChars))
    }

    /// A dimension that uses a spec-standard unit (pt/px/rem/em).
    public static func isStandard(_ raw: String) -> Bool {
        guard let parts = parseParts(raw) else { return false }
        return standardUnits.contains(parts.unit)
    }

    /// A dimension parseable with any known CSS length/percentage unit.
    public static func isParseable(_ raw: String) -> Bool {
        guard let parts = parseParts(raw) else { return false }
        return cssUnits.contains(parts.unit)
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
}

/// True if a string is a token reference like `{section.token}`.
/// Equivalent to the regex `^\{[a-zA-Z0-9._-]+\}$`.
public func isTokenReference(_ raw: String) -> Bool {
    guard raw.hasPrefix("{"), raw.hasSuffix("}"), raw.count >= 3 else { return false }
    let inner = raw.dropFirst().dropLast()
    guard !inner.isEmpty else { return false }
    for c in inner {
        let ok = (c.isASCII && (c.isLetter || c.isNumber)) || c == "." || c == "_" || c == "-"
        if !ok { return false }
    }
    return true
}

/// True if a string is a valid CSS color.
public func isValidColor(_ raw: String) -> Bool {
    parseCssColor(raw) != nil
}
