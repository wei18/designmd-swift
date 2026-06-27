// Phase 3 exporter tests: DTCG parity (golden) + Apple-native swift/asset-catalog.

import XCTest
import Foundation
@testable import DesignMD

final class ExportTests: XCTestCase {

    // DTCG output must match the golden captured from the upstream TS exporter.
    func testDTCGMatchesGolden() throws {
        let names = ["atmospheric-glass", "paws-and-paths", "totality-festival",
                     "HERITAGE", "edge-colors", "apple-points"]
        for name in names {
            let md = try fixture(name, "md")
            let golden = try String(contentsOf: try goldenURL(name), encoding: .utf8)
            let report = lint(try String(contentsOf: md, encoding: .utf8))
            let produced = exportDTCG(report.designSystem).serialize() + "\n"
            XCTAssertEqual(produced, golden, "[\(name)] DTCG output drifted from golden")
        }
    }

    func testSwiftThemeContent() throws {
        let md = try fixture("apple-points", "md")
        let report = lint(try String(contentsOf: md, encoding: .utf8))
        let src = exportSwiftTheme(report.designSystem)
        XCTAssertTrue(src.contains("import SwiftUI"))
        XCTAssertTrue(src.contains("public enum Theme"))
        XCTAssertTrue(src.contains("public enum Colors"))
        // 17pt → points 17 in a system font
        XCTAssertTrue(src.contains("Font.system(size: 17, weight: .regular)"))
        // 12pt rounded → CGFloat 12
        XCTAssertTrue(src.contains("public static let md: CGFloat = 12"))
        // sRGB color literal with hex comment
        XCTAssertTrue(src.contains("Color(.sRGB, red:"))
        XCTAssertTrue(src.contains("// #1a1c1e"))
    }

    func testIdentifierSanitization() {
        XCTAssertEqual(ident("on-surface"), "onSurface")
        XCTAssertEqual(ident("body-md"), "bodyMd")
        XCTAssertEqual(ident("headline-display"), "headlineDisplay")
        XCTAssertEqual(ident("primary"), "primary")
        XCTAssertEqual(ident("default"), "`default`")     // Swift keyword
    }

    func testSystemFontDesigns() throws {
        let content = """
        ---
        name: Fonts
        colors:
          primary: "#000000"
        typography:
          mono: { fontFamily: SF Mono, fontSize: 12pt, fontWeight: "500" }
          serif: { fontFamily: New York, fontSize: 17pt }
          round: { fontFamily: SF Pro Rounded, fontSize: 17pt, fontWeight: "700" }
          custom: { fontFamily: Inter, fontSize: 16pt, fontWeight: "400" }
        ---
        ## Typography
        """
        let src = exportSwiftTheme(lint(content).designSystem)
        XCTAssertTrue(src.contains("design: .monospaced"))
        XCTAssertTrue(src.contains("design: .serif"))
        XCTAssertTrue(src.contains("design: .rounded"))
        XCTAssertTrue(src.contains("Font.custom(\"Inter\", size: 16).weight(.regular)"))
    }

    func testAssetCatalogStructure() throws {
        let md = try fixture("atmospheric-glass", "md")
        let report = lint(try String(contentsOf: md, encoding: .utf8))
        let files = exportAssetCatalog(report.designSystem)
        // One root Contents.json + one per color token.
        XCTAssertEqual(files.count, report.designSystem.colors.size + 1)
        XCTAssertEqual(files.first?.path, "Contents.json")

        // Every colorset file is valid JSON with universal sRGB components.
        for f in files where f.path.hasSuffix(".colorset/Contents.json") {
            let data = f.contents.data(using: .utf8)!
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let colors = obj["colors"] as! [[String: Any]]
            let color = colors[0]["color"] as! [String: Any]
            XCTAssertEqual(color["color-space"] as? String, "srgb")
            let comps = color["components"] as! [String: Any]
            XCTAssertNotNil(comps["red"]); XCTAssertNotNil(comps["alpha"])
        }
    }

    // ── Helpers ────────────────────────────────────────────────────

    private func fixture(_ name: String, _ ext: String) throws -> URL {
        fixtureFile("\(name).\(ext)")
    }

    private func goldenURL(_ name: String) throws -> URL {
        fixtureFile("\(name).dtcg.golden.json")
    }
}
