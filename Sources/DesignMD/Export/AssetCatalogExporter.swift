// Asset Catalog exporter — emits an `.xcassets` color-set tree so each color
// token resolves via `Color("token-name")` / `UIColor(named:)` in an app.

import Foundation

/// A generated file with a path relative to the `.xcassets` bundle root.
public struct GeneratedFile: Equatable, Sendable {
    public let path: String
    public let contents: String
    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

/// Produce the files for an Asset Catalog of the design system's colors.
/// Paths are relative to the `.xcassets` bundle root.
public func exportAssetCatalog(_ state: DesignSystemState) -> [GeneratedFile] {
    var files: [GeneratedFile] = [
        GeneratedFile(path: "Contents.json", contents: catalogInfoJSON()),
    ]
    for (name, color) in state.colors {
        let folder = sanitizeAssetName(name)
        files.append(GeneratedFile(
            path: "\(folder).colorset/Contents.json",
            contents: colorsetJSON(color)))
    }
    return files
}

private func catalogInfoJSON() -> String {
    JSONValue.object([
        ("info", .object([("author", .str("xcode")), ("version", .int(1))])),
    ]).serialize() + "\n"
}

private func colorsetJSON(_ c: ResolvedColor) -> String {
    let alpha = c.a ?? 1
    let color = JSONValue.object([
        ("color-space", .str("srgb")),
        ("components", .object([
            ("red", .str(comp(Double(c.r) / 255))),
            ("green", .str(comp(Double(c.g) / 255))),
            ("blue", .str(comp(Double(c.b) / 255))),
            ("alpha", .str(comp(alpha))),
        ])),
    ])
    let entry = JSONValue.object([
        ("color", color),
        ("idiom", .str("universal")),
    ])
    return JSONValue.object([
        ("colors", .array([entry])),
        ("info", .object([("author", .str("xcode")), ("version", .int(1))])),
    ]).serialize() + "\n"
}

private func comp(_ v: Double) -> String {
    String(format: "%.3f", v)
}

private func sanitizeAssetName(_ name: String) -> String {
    String(name.map { $0 == "/" || $0 == "\\" ? "_" : $0 })
}
