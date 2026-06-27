// CSS color parser → sRGB + WCAG relative luminance.
// Faithful port of `model/color-parser.ts`.

import Foundation

private let cssNamedColors: [String: String] = [
    "aliceblue": "#f0f8ff", "antiquewhite": "#faebd7", "aqua": "#00ffff", "aquamarine": "#7fffd4", "azure": "#f0ffff",
    "beige": "#f5f5dc", "bisque": "#ffe4c4", "black": "#000000", "blanchedalmond": "#ffebcd", "blue": "#0000ff",
    "blueviolet": "#8a2be2", "brown": "#a52a2a", "burlywood": "#deb887", "cadetblue": "#5f9ea0", "chartreuse": "#7fff00",
    "chocolate": "#d2691e", "coral": "#ff7f50", "cornflowerblue": "#6495ed", "cornsilk": "#fff8dc", "crimson": "#dc143c",
    "cyan": "#00ffff", "darkblue": "#00008b", "darkcyan": "#008b8b", "darkgoldenrod": "#b8860b", "darkgray": "#a9a9a9",
    "darkgrey": "#a9a9a9", "darkgreen": "#006400", "darkkhaki": "#bdb76b", "darkmagenta": "#8b008b", "darkolivegreen": "#556b2f",
    "darkorange": "#ff8c00", "darkorchid": "#9932cc", "darkred": "#8b0000", "darksalmon": "#e9967a", "darkseagreen": "#8fbc8f",
    "darkslateblue": "#483d8b", "darkslategrey": "#2f4f4f", "darkslategray": "#2f4f4f", "darkturquoise": "#00ced1",
    "darkviolet": "#9400d3", "deeppink": "#ff1493", "deepskyblue": "#00bfff", "dimgray": "#696969", "dimgrey": "#696969",
    "dodgerblue": "#1e90ff", "firebrick": "#b22222", "floralwhite": "#fffaf0", "forestgreen": "#228b22", "fuchsia": "#ff00ff",
    "gainsboro": "#dcdcdc", "ghostwhite": "#f8f8ff", "gold": "#ffd700", "goldenrod": "#daa520", "gray": "#808080",
    "grey": "#808080", "green": "#008000", "greenyellow": "#adff2f", "honeydew": "#f0fff0", "hotpink": "#ff69b4",
    "indianred": "#cd5c5c", "indigo": "#4b0082", "ivory": "#fffff0", "khaki": "#f0e68c", "lavender": "#e6e6fa",
    "lavenderblush": "#fff0f5", "lawngreen": "#7cfc00", "lemonchiffon": "#fffacd", "lightblue": "#add8e6", "lightcoral": "#f08080",
    "lightcyan": "#e0ffff", "lightgoldenrodyellow": "#fafad2", "lightgray": "#d3d3d3", "lightgrey": "#d3d3d3", "lightgreen": "#90ee90",
    "lightpink": "#ffb6c1", "lightsalmon": "#ffa07a", "lightseagreen": "#20b2aa", "lightskyblue": "#87cefa", "lightslate": "#778899",
    "lightslategray": "#778899", "lightslategrey": "#778899", "lightsteelblue": "#b0c4de", "lightyellow": "#ffffe0", "lime": "#00ff00",
    "limegreen": "#32cd32", "linen": "#faf0e6", "magenta": "#ff00ff", "maroon": "#800000",
    "mediumaquamarine": "#66cdaa", "mediumblue": "#0000cd", "mediumorchid": "#ba55d3", "mediumpurple": "#9370db", "mediumseagreen": "#3cb371",
    "mediumslateblue": "#7b68ee", "mediumspringgreen": "#00fa9a", "mediumturquoise": "#48d1cc", "mediumvioletred": "#c71585", "midnightblue": "#191970",
    "mintcream": "#f5fffa", "mistyrose": "#ffe4e1", "moccasin": "#ffe4b5", "navajowhite": "#ffdead", "navy": "#000080",
    "oldlace": "#fdf5e6", "olive": "#808000", "olivedrab": "#6b8e23", "orange": "#ffa500", "orangered": "#ff4500",
    "orchid": "#da70d6", "palegoldenrod": "#eee8aa", "palegreen": "#98fb98", "paleturquoise": "#afeeee", "palevioletred": "#db7093",
    "papayawhip": "#ffefd5", "peachpuff": "#ffdab9", "peru": "#cd853f", "pink": "#ffc0cb", "plum": "#dda0dd",
    "powderblue": "#b0e0e6", "purple": "#800080", "rebeccapurple": "#663399", "red": "#ff0000", "rosybrown": "#bc8f8f",
    "royalblue": "#4169e1", "saddlebrown": "#8b4513", "salmon": "#fa8072", "sandybrown": "#f4a460", "seagreen": "#2e8b57",
    "seashell": "#fff5ee", "sienna": "#a0522d", "silver": "#c0c0c0", "skyblue": "#87ceeb", "slateblue": "#6a5acd",
    "slategray": "#708090", "slategrey": "#708090", "snow": "#fffafa", "springgreen": "#00ff7f", "steelblue": "#4682b4",
    "tan": "#d2b48c", "teal": "#008080", "thistle": "#d8bfd8", "tomato": "#ff6347", "turquoise": "#40e0d0",
    "violet": "#ee82ee", "wheat": "#f5deb3", "white": "#ffffff", "whitesmoke": "#f5f5f5", "yellow": "#ffff00",
    "yellowgreen": "#9acd32", "transparent": "#00000000",
]

/// Parse a CSS color string into its sRGB representation + WCAG relative
/// luminance. Returns nil if the color is invalid.
public func parseCssColor(_ colorStr: String) -> ResolvedColor? {
    let clean = colorStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if clean.isEmpty { return nil }

    // 1. Hex
    if clean.hasPrefix("#") {
        guard isHex(clean) else { return nil }
        return parseHex(clean)
    }

    // 2. Named colors
    if let named = cssNamedColors[clean] {
        return parseHex(named)
    }

    // 3. Functional notations
    guard let parsed = tokenizeFunc(clean) else { return nil }
    let name = parsed.name
    let args = parsed.args

    switch name {
    case "rgb", "rgba":
        guard args.count == 3 || args.count == 4 else { return nil }
        let rRaw = parsePercentOrNumber(args[0], 255)
        let gRaw = parsePercentOrNumber(args[1], 255)
        let bRaw = parsePercentOrNumber(args[2], 255)
        let aVal = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !rRaw.isNaN, !gRaw.isNaN, !bRaw.isNaN, !aVal.isNaN else { return nil }
        let r = clampInt(rRaw.rounded())
        let g = clampInt(gRaw.rounded())
        let b = clampInt(bRaw.rounded())
        let a = min(1, max(0, aVal))
        return makeResult(r, g, b, a)

    case "hsl", "hsla":
        guard args.count == 3 || args.count == 4 else { return nil }
        let h = parseHue(args[0])
        let s = parsePercentOrNumber(args[1], 1)
        let l = parsePercentOrNumber(args[2], 1)
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !h.isNaN, !s.isNaN, !l.isNaN, !a.isNaN else { return nil }
        let rgb = hslToRgb(h, s, l)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "hwb":
        guard args.count == 3 || args.count == 4 else { return nil }
        let h = parseHue(args[0])
        let w = parsePercentOrNumber(args[1], 1)
        let b = parsePercentOrNumber(args[2], 1)
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !h.isNaN, !w.isNaN, !b.isNaN, !a.isNaN else { return nil }
        let rgb = hwbToRgb(h, w, b)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "lab":
        guard args.count == 3 || args.count == 4 else { return nil }
        let l = parsePercentOrNumber(args[0], 100)
        let aVal = jsParseFloat(args[1])
        let bVal = jsParseFloat(args[2])
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !l.isNaN, !aVal.isNaN, !bVal.isNaN, !a.isNaN else { return nil }
        let rgb = labToRgb(l, aVal, bVal)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "lch":
        guard args.count == 3 || args.count == 4 else { return nil }
        let l = parsePercentOrNumber(args[0], 100)
        let c = jsParseFloat(args[1])
        let h = parseHue(args[2])
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !l.isNaN, !c.isNaN, !h.isNaN, !a.isNaN else { return nil }
        let rgb = lchToRgb(l, c, h)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "oklab":
        guard args.count == 3 || args.count == 4 else { return nil }
        let l = parsePercentOrNumber(args[0], 1)
        let aVal = jsParseFloat(args[1])
        let bVal = jsParseFloat(args[2])
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !l.isNaN, !aVal.isNaN, !bVal.isNaN, !a.isNaN else { return nil }
        let rgb = oklabToRgb(l, aVal, bVal)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "oklch":
        guard args.count == 3 || args.count == 4 else { return nil }
        let l = parsePercentOrNumber(args[0], 1)
        let c = jsParseFloat(args[1])
        let h = parseHue(args[2])
        let a = args.count == 4 ? parseAlpha(args[3]) : 1
        guard !l.isNaN, !c.isNaN, !h.isNaN, !a.isNaN else { return nil }
        let rgb = oklchToRgb(l, c, h)
        return makeResult(rgb.r, rgb.g, rgb.b, a)

    case "color-mix":
        return parseColorMix(clean)

    default:
        return nil
    }
}

// ── Hex ────────────────────────────────────────────────────────────

private func isHex(_ clean: String) -> Bool {
    guard clean.hasPrefix("#") else { return false }
    let body = clean.dropFirst()
    let n = body.count
    guard n == 3 || n == 4 || n == 6 || n == 8 else { return false }
    return body.allSatisfy { $0.isHexDigit }
}

private func parseHex(_ hexStr: String) -> ResolvedColor {
    var hex = hexStr
    let chars = Array(hexStr)
    if chars.count == 4 {
        hex = "#\(chars[1])\(chars[1])\(chars[2])\(chars[2])\(chars[3])\(chars[3])"
    } else if chars.count == 5 {
        hex = "#\(chars[1])\(chars[1])\(chars[2])\(chars[2])\(chars[3])\(chars[3])\(chars[4])\(chars[4])"
    }
    let h = Array(hex)
    let r = Int(String(h[1...2]), radix: 16) ?? 0
    let g = Int(String(h[3...4]), radix: 16) ?? 0
    let b = Int(String(h[5...6]), radix: 16) ?? 0
    var a: Double? = nil
    if h.count == 9 {
        a = Double(Int(String(h[7...8]), radix: 16) ?? 0) / 255
    }
    return makeResult(r, g, b, a)
}

// ── Result + luminance ─────────────────────────────────────────────

private func makeResult(_ r: Int, _ g: Int, _ b: Int, _ a: Double?) -> ResolvedColor {
    var hex = String(format: "#%02x%02x%02x", r, g, b)
    if let a, a < 1 {
        let hexA = Int((a * 255).rounded())
        hex += String(format: "%02x", hexA)
    }
    return ResolvedColor(hex: hex, r: r, g: g, b: b, a: a, luminance: computeLuminance(r, g, b))
}

private func computeLuminance(_ r: Int, _ g: Int, _ b: Int) -> Double {
    func linearize(_ c: Int) -> Double {
        let s = Double(c) / 255
        return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

private func clampInt(_ v: Double) -> Int {
    Int(min(255, max(0, v)))
}

// ── Numeric parsing ────────────────────────────────────────────────

/// Mimics JS `parseFloat`: parse the leading numeric portion (including an
/// exponent and `Infinity`), NaN if none.
func jsParseFloat(_ s: String) -> Double {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("Infinity") || t.hasPrefix("+Infinity") { return .infinity }
    if t.hasPrefix("-Infinity") { return -.infinity }

    let chars = Array(t)
    let n = chars.count
    var i = 0
    if i < n, chars[i] == "+" || chars[i] == "-" { i += 1 }

    // Mantissa: digits, optional single dot, digits.
    var seenDigit = false
    var seenDot = false
    var lastValid = i
    while i < n {
        let c = chars[i]
        if c.isNumber && c.isASCII {
            seenDigit = true; i += 1; lastValid = i
        } else if c == "." && !seenDot {
            seenDot = true; i += 1; if seenDigit { lastValid = i }
        } else {
            break
        }
    }
    guard seenDigit else { return .nan }

    // Optional exponent: [eE][+-]?digits — only consumed if it has digits.
    if i < n, chars[i] == "e" || chars[i] == "E" {
        var j = i + 1
        if j < n, chars[j] == "+" || chars[j] == "-" { j += 1 }
        var expDigits = false
        while j < n, chars[j].isNumber && chars[j].isASCII { expDigits = true; j += 1 }
        if expDigits { lastValid = j }
    }

    return Double(String(chars[0..<lastValid])) ?? .nan
}

/// Mimics JS `Number()`: strict full-string numeric parse ("" → 0, junk → NaN).
private func jsNumber(_ s: String) -> Double {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return 0 }
    return Double(t) ?? .nan
}

private func parseHue(_ s: String) -> Double {
    let lower = s.trimmingCharacters(in: .whitespaces).lowercased()
    var val: Double
    if lower.hasSuffix("deg") {
        val = jsParseFloat(String(lower.dropLast(3)))
    } else if lower.hasSuffix("grad") {
        val = jsParseFloat(String(lower.dropLast(4))) * 360 / 400
    } else if lower.hasSuffix("rad") {
        val = jsParseFloat(String(lower.dropLast(3))) * 180 / .pi
    } else if lower.hasSuffix("turn") {
        val = jsParseFloat(String(lower.dropLast(4))) * 360
    } else {
        val = jsParseFloat(lower)
    }
    val = val.truncatingRemainder(dividingBy: 360)
    if val < 0 { val += 360 }
    return val
}

private func parsePercentOrNumber(_ s: String, _ refMax: Double) -> Double {
    let trim = s.trimmingCharacters(in: .whitespaces)
    if trim.hasSuffix("%") {
        return jsParseFloat(String(trim.dropLast())) / 100 * refMax
    }
    return jsParseFloat(trim)
}

private func parseAlpha(_ s: String?) -> Double {
    guard let s else { return 1 }
    let trim = s.trimmingCharacters(in: .whitespaces)
    if trim.hasSuffix("%") {
        return jsParseFloat(String(trim.dropLast())) / 100
    }
    return jsParseFloat(trim)
}

// ── Function tokenizer ─────────────────────────────────────────────

private func tokenizeFunc(_ str: String) -> (name: String, args: [String])? {
    let s = str.trimmingCharacters(in: .whitespaces)
    guard s.hasSuffix(")"), let openIdx = s.firstIndex(of: "(") else { return nil }
    let name = String(s[s.startIndex..<openIdx]).lowercased()
    guard name.count >= 3, name.count <= 15,
          name.allSatisfy({ ($0.isASCII && $0.isLetter) || $0 == "-" }) else { return nil }
    let inner = String(s[s.index(after: openIdx)..<s.index(before: s.endIndex)])
        .trimmingCharacters(in: .whitespaces)

    var coordStr = inner
    var alphaStr: String? = nil

    // Parenthesis-aware search for the first depth-0 '/'.
    var slantIndex: String.Index? = nil
    var depth = 0
    var i = inner.startIndex
    while i < inner.endIndex {
        let ch = inner[i]
        if ch == "(" { depth += 1 }
        else if ch == ")" { depth -= 1 }
        else if depth == 0 && ch == "/" { slantIndex = i; break }
        i = inner.index(after: i)
    }
    if let slantIndex {
        coordStr = String(inner[inner.startIndex..<slantIndex]).trimmingCharacters(in: .whitespaces)
        alphaStr = String(inner[inner.index(after: slantIndex)...]).trimmingCharacters(in: .whitespaces)
    }

    var args = splitList(coordStr)
    if let alphaStr { args.append(alphaStr) }
    return (name, args)
}

/// Split a space/comma separated parameter list, ignoring nested parens.
private func splitList(_ str: String) -> [String] {
    var results: [String] = []
    var current = ""
    var depth = 0
    for ch in str {
        if ch == "(" { depth += 1; current.append(ch) }
        else if ch == ")" { depth -= 1; current.append(ch) }
        else if depth == 0 && (ch == "," || ch.isWhitespace) {
            let t = current.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { results.append(t); current = "" }
        } else {
            current.append(ch)
        }
    }
    let t = current.trimmingCharacters(in: .whitespaces)
    if !t.isEmpty { results.append(t) }
    return results
}

private func splitByComma(_ str: String) -> [String] {
    var results: [String] = []
    var current = ""
    var depth = 0
    for ch in str {
        if ch == "(" { depth += 1; current.append(ch) }
        else if ch == ")" { depth -= 1; current.append(ch) }
        else if depth == 0 && ch == "," {
            results.append(current.trimmingCharacters(in: .whitespaces))
            current = ""
        } else {
            current.append(ch)
        }
    }
    let t = current.trimmingCharacters(in: .whitespaces)
    if !t.isEmpty { results.append(t) }
    return results
}

// ── color-mix ──────────────────────────────────────────────────────

private func parseColorMix(_ clean: String) -> ResolvedColor? {
    // clean == "color-mix(in srgb, c1 w1, c2 w2)"; strip "color-mix(" + trailing ")".
    let chars = Array(clean)
    guard chars.count > 11 else { return nil }
    let inner = String(chars[10..<(chars.count - 1)])
    let subArgs = splitByComma(inner)
    guard subArgs.count == 3 else { return nil }

    let spaceTokens = subArgs[0].split(whereSeparator: { $0.isWhitespace }).map(String.init)
    guard spaceTokens.count == 2, spaceTokens[0] == "in", spaceTokens[1] == "srgb" else { return nil }

    guard let parsed1 = parseColorWithWeight(subArgs[1]),
          let parsed2 = parseColorWithWeight(subArgs[2]),
          let c1 = parseCssColor(parsed1.colorStr),
          let c2 = parseCssColor(parsed2.colorStr) else { return nil }

    var w1 = parsed1.weight
    var w2 = parsed2.weight

    if w1 == nil && w2 == nil { w1 = 50; w2 = 50 }
    else if let v1 = w1, w2 == nil { w2 = 100 - v1 }
    else if let v2 = w2, w1 == nil { w1 = 100 - v2 }
    else if let v1 = w1, let v2 = w2 {
        let sum = v1 + v2
        if sum == 0 { return nil }
        w1 = v1 / sum * 100
        w2 = v2 / sum * 100
    }

    let f1 = w1! / 100
    let f2 = w2! / 100
    let a1 = c1.a ?? 1
    let a2 = c2.a ?? 1
    let aMix = a1 * f1 + a2 * f2
    var r = 0, g = 0, b = 0
    if aMix > 0 {
        r = Int(((Double(c1.r) * a1 * f1 + Double(c2.r) * a2 * f2) / aMix).rounded())
        g = Int(((Double(c1.g) * a1 * f1 + Double(c2.g) * a2 * f2) / aMix).rounded())
        b = Int(((Double(c1.b) * a1 * f1 + Double(c2.b) * a2 * f2) / aMix).rounded())
    }
    return makeResult(min(255, max(0, r)), min(255, max(0, g)), min(255, max(0, b)), min(1, max(0, aMix)))
}

private func parseColorWithWeight(_ subArg: String) -> (colorStr: String, weight: Double?)? {
    let parts = splitList(subArg.trimmingCharacters(in: .whitespaces))
    guard !parts.isEmpty, parts.count <= 2 else { return nil }
    if parts.count == 1 { return (parts[0], nil) }

    let p0 = parts[0]
    let p1 = parts[1]
    let isP0Weight = p0.hasSuffix("%") || (!jsNumber(p0).isNaN && !p0.isEmpty)
    let isP1Weight = p1.hasSuffix("%") || (!jsNumber(p1).isNaN && !p1.isEmpty)

    if isP0Weight && !isP1Weight {
        let w = p0.hasSuffix("%") ? jsParseFloat(String(p0.dropLast())) : jsParseFloat(p0) * 100
        return (p1, w)
    } else if isP1Weight && !isP0Weight {
        let w = p1.hasSuffix("%") ? jsParseFloat(String(p1.dropLast())) : jsParseFloat(p1) * 100
        return (p0, w)
    }
    return nil
}

// ── Color-space conversions ────────────────────────────────────────

private func hslToRgb(_ h: Double, _ s: Double, _ l: Double) -> (r: Int, g: Int, b: Int) {
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    var r_ = 0.0, g_ = 0.0, b_ = 0.0
    if h < 60 { r_ = c; g_ = x; b_ = 0 }
    else if h < 120 { r_ = x; g_ = c; b_ = 0 }
    else if h < 180 { r_ = 0; g_ = c; b_ = x }
    else if h < 240 { r_ = 0; g_ = x; b_ = c }
    else if h < 300 { r_ = x; g_ = 0; b_ = c }
    else { r_ = c; g_ = 0; b_ = x }
    return (clampInt(((r_ + m) * 255).rounded()),
            clampInt(((g_ + m) * 255).rounded()),
            clampInt(((b_ + m) * 255).rounded()))
}

private func hwbToRgb(_ h: Double, _ w: Double, _ b: Double) -> (r: Int, g: Int, b: Int) {
    if w + b >= 1 {
        let sum = w + b
        let val = clampInt((w / sum * 255).rounded())
        return (val, val, val)
    }
    let pure = hslToRgb(h, 1, 0.5)
    let r = (Double(pure.r) / 255 * (1 - w - b) * 255 + w * 255).rounded()
    let g = (Double(pure.g) / 255 * (1 - w - b) * 255 + w * 255).rounded()
    let bv = (Double(pure.b) / 255 * (1 - w - b) * 255 + w * 255).rounded()
    return (clampInt(r), clampInt(g), clampInt(bv))
}

private func labToRgb(_ l: Double, _ a: Double, _ b: Double) -> (r: Int, g: Int, b: Int) {
    let fy = (l + 16) / 116
    let fx = a / 500 + fy
    let fz = fy - b / 200
    let e = 216.0 / 24389.0
    let k = 24389.0 / 27.0
    let fx3 = fx * fx * fx
    let fz3 = fz * fz * fz
    let xr = fx3 > e ? fx3 : (116 * fx - 16) / k
    let yr = l > k * e ? fy * fy * fy : l / k
    let zr = fz3 > e ? fz3 : (116 * fz - 16) / k
    let Xn = 0.96422, Yn = 1.0, Zn = 0.82521
    let x = xr * Xn, y = yr * Yn, z = zr * Zn
    let x65 = 0.9555726312052288 * x - 0.02303316850884054 * y + 0.06316100215997244 * z
    let y65 = -0.02828971739420664 * x + 1.0099416310812543 * y + 0.021007716449297163 * z
    let z65 = 0.012298224741016325 * x - 0.02048298287477757 * y + 1.3299098463422234 * z
    let rLin = 3.2404542 * x65 - 1.5371385 * y65 - 0.4985314 * z65
    let gLin = -0.9692660 * x65 + 1.8760108 * y65 + 0.0415560 * z65
    let bLin = 0.0556434 * x65 - 0.2040259 * y65 + 1.0572252 * z65
    return (clampInt((gammaCorrect(rLin) * 255).rounded()),
            clampInt((gammaCorrect(gLin) * 255).rounded()),
            clampInt((gammaCorrect(bLin) * 255).rounded()))
}

private func lchToRgb(_ l: Double, _ c: Double, _ h: Double) -> (r: Int, g: Int, b: Int) {
    let hRad = h * .pi / 180
    return labToRgb(l, c * cos(hRad), c * sin(hRad))
}

private func oklabToRgb(_ l: Double, _ a: Double, _ b: Double) -> (r: Int, g: Int, b: Int) {
    let l_ = l + 0.3963377774 * a + 0.2158037573 * b
    let m_ = l - 0.1055613458 * a - 0.0638541728 * b
    let s_ = l - 0.0894841775 * a - 1.2914855480 * b
    let l3 = l_ * l_ * l_
    let m3 = m_ * m_ * m_
    let s3 = s_ * s_ * s_
    let rLin = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
    let gLin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
    let bLin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
    return (clampInt((gammaCorrect(rLin) * 255).rounded()),
            clampInt((gammaCorrect(gLin) * 255).rounded()),
            clampInt((gammaCorrect(bLin) * 255).rounded()))
}

private func oklchToRgb(_ l: Double, _ c: Double, _ h: Double) -> (r: Int, g: Int, b: Int) {
    let hRad = h * .pi / 180
    return oklabToRgb(l, c * cos(hRad), c * sin(hRad))
}

private func gammaCorrect(_ val: Double) -> Double {
    val <= 0.0031308 ? 12.92 * val : 1.055 * pow(val, 1 / 2.4) - 0.055
}
