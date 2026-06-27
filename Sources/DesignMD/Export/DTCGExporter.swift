// DTCG exporter — W3C Design Tokens Format Module 2025.10.
// Faithful port of `dtcg/handler.ts`; emits the same JSON shape.

import Foundation

private let dtcgSchemaURL = "https://www.designtokens.org/schemas/2025.10/format.json"

/// Map a resolved design system to a DTCG tokens.json (ordered JSONValue).
public func exportDTCG(_ state: DesignSystemState) -> JSONValue {
    var file: [(String, JSONValue)] = [("$schema", .str(dtcgSchemaURL))]

    let name = state.name ?? ""
    let description = state.description ?? ""
    if !name.isEmpty || !description.isEmpty {
        file.append(("$description", .str(description.isEmpty ? name : description)))
    }

    if state.colors.size > 0 {
        var group: [(String, JSONValue)] = [("$type", .str("color"))]
        for (cname, color) in state.colors {
            group.append((cname, .object([("$value", colorValue(color))])))
        }
        file.append(("color", .object(group)))
    }

    if let spacing = dimensionGroup(state.spacing) {
        file.append(("spacing", spacing))
    }
    if let rounded = dimensionGroup(state.rounded) {
        file.append(("rounded", rounded))
    }

    if state.typography.size > 0 {
        var group: [(String, JSONValue)] = []
        for (tname, typo) in state.typography {
            group.append((tname, .object([
                ("$type", .str("typography")),
                ("$value", typographyValue(typo)),
            ])))
        }
        file.append(("typography", .object(group)))
    }

    return .object(file)
}

private func round3(_ n: Double) -> Double { (n * 1000).rounded() / 1000 }

private func colorValue(_ color: ResolvedColor) -> JSONValue {
    .object([
        ("colorSpace", .str("srgb")),
        ("components", .array([
            .double(round3(Double(color.r) / 255)),
            .double(round3(Double(color.g) / 255)),
            .double(round3(Double(color.b) / 255)),
        ])),
        ("hex", .str(color.hex.lowercased())),
    ])
}

private func dimValue(_ dim: ResolvedDimension) -> JSONValue {
    .object([("value", .double(dim.value)), ("unit", .str(dim.unit))])
}

private func dimensionGroup(_ dims: OrderedDict<ResolvedDimension>) -> JSONValue? {
    guard dims.size > 0 else { return nil }
    var group: [(String, JSONValue)] = [("$type", .str("dimension"))]
    for (name, dim) in dims {
        group.append((name, .object([("$value", dimValue(dim))])))
    }
    return .object(group)
}

private func typographyValue(_ typo: ResolvedTypography) -> JSONValue {
    var value: [(String, JSONValue)] = []
    if let ff = typo.fontFamily { value.append(("fontFamily", .str(ff))) }
    if let fs = typo.fontSize { value.append(("fontSize", dimValue(fs))) }
    if let fw = typo.fontWeight { value.append(("fontWeight", .double(fw))) }
    if let ls = typo.letterSpacing { value.append(("letterSpacing", dimValue(ls))) }
    if let lh = typo.lineHeight { value.append(("lineHeight", .double(lh.value))) }
    return .object(value)
}
