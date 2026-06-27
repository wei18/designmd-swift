import XCTest
@testable import DesignMD

final class ColorAndModelTests: XCTestCase {

    func testHexExpansionAndChannels() {
        let c = parseCssColor("#1A1C1E")!
        XCTAssertEqual(c.r, 0x1A)
        XCTAssertEqual(c.g, 0x1C)
        XCTAssertEqual(c.b, 0x1E)
        XCTAssertEqual(c.hex, "#1a1c1e")

        let short = parseCssColor("#abc")!
        XCTAssertEqual(short.hex, "#aabbcc")
    }

    func testHexAlpha() {
        let c = parseCssColor("#ffffffa6")!
        XCTAssertEqual(c.a!, Double(0xA6) / 255, accuracy: 1e-9)
    }

    func testLuminanceAndContrast() {
        let white = parseCssColor("#ffffff")!
        let black = parseCssColor("#000000")!
        XCTAssertEqual(white.luminance, 1.0, accuracy: 1e-9)
        XCTAssertEqual(black.luminance, 0.0, accuracy: 1e-9)
        XCTAssertEqual(contrastRatio(white, black), 21.0, accuracy: 1e-9)
    }

    func testRgbAndPercent() {
        XCTAssertEqual(parseCssColor("rgb(255 0 0)")!.hex, "#ff0000")
        XCTAssertEqual(parseCssColor("rgb(100% 0% 0%)")!.hex, "#ff0000")
        XCTAssertEqual(parseCssColor("rgb(255, 0, 0)")!.hex, "#ff0000")
    }

    func testHslGreen() {
        let c = parseCssColor("hsl(120 100% 50%)")!
        XCTAssertEqual(c.r, 0); XCTAssertEqual(c.g, 255); XCTAssertEqual(c.b, 0)
    }

    func testNamedColor() {
        XCTAssertEqual(parseCssColor("cornflowerblue")!.hex, "#6495ed")
    }

    func testOklchParses() {
        XCTAssertNotNil(parseCssColor("oklch(0.62 0.18 250)"))
    }

    func testColorMix() {
        // 50/50 red+blue mix → purple-ish, must parse.
        XCTAssertNotNil(parseCssColor("color-mix(in srgb, red, blue)"))
    }

    func testInvalidColors() {
        XCTAssertNil(parseCssColor("notacolor"))
        XCTAssertNil(parseCssColor("#12345"))   // 5 hex digits invalid
        XCTAssertNil(parseCssColor(""))
    }

    func testDimensionParsing() {
        XCTAssertEqual(Dimensions.parseParts("12px")!.value, 12)
        XCTAssertEqual(Dimensions.parseParts("12px")!.unit, "px")
        XCTAssertEqual(Dimensions.parseParts("-0.5rem")!.value, -0.5, accuracy: 1e-9)
        XCTAssertEqual(Dimensions.parseParts(".5em")!.value, 0.5, accuracy: 1e-9)
        XCTAssertNil(Dimensions.parseParts("12"))     // no unit
        XCTAssertNil(Dimensions.parseParts("auto"))   // not a dimension
    }

    func testStandardUnitsIncludePt() {
        XCTAssertTrue(Dimensions.isStandard("12pt"), "pt must be standard in the Apple edition")
        XCTAssertTrue(Dimensions.isStandard("12px"))
        XCTAssertFalse(Dimensions.isStandard("12vh"))
    }

    func testTokenReference() {
        XCTAssertTrue(isTokenReference("{colors.primary}"))
        XCTAssertTrue(isTokenReference("{rounded.md}"))
        XCTAssertFalse(isTokenReference("colors.primary"))
        XCTAssertFalse(isTokenReference("{}"))
        XCTAssertFalse(isTokenReference("#fff"))
    }

    func testReferenceResolutionAndCycle() {
        let content = """
        ---
        name: Refs
        colors:
          primary: "#102030"
          alias: "{colors.primary}"
          loopA: "{colors.loopB}"
          loopB: "{colors.loopA}"
        ---

        ## Colors
        """
        let report = lint(content)
        // alias resolves to primary's color
        XCTAssertEqual(report.designSystem.colors.get("alias")?.hex, "#102030")
        // cyclic refs do not resolve into the colors map
        XCTAssertNil(report.designSystem.colors.get("loopA"))
        XCTAssertNil(report.designSystem.colors.get("loopB"))
    }

    func testContrastRuleFires() {
        let content = """
        ---
        name: LowContrast
        colors:
          primary: "#777777"
        components:
          btn:
            backgroundColor: "#777777"
            textColor: "#808080"
        ---

        ## Components
        """
        let report = lint(content)
        XCTAssertTrue(report.findings.contains {
            $0.message.contains("below WCAG AA minimum")
        })
    }

    func testDiffRegressionDetection() {
        let before = """
        ---
        name: A
        colors:
          primary: "#000000"
        ---
        ## Colors
        """
        let after = """
        ---
        name: A
        colors:
          primary: "#000000"
          orphan: "#abcdef"
        components:
          x:
            backgroundColor: "#000000"
            textColor: "#010101"
        ---
        ## Colors
        """
        let report = computeDiff(before: before, after: after)
        XCTAssertTrue(report.tokens.colors.added.contains("orphan"))
        XCTAssertTrue(report.regression, "added warnings should count as a regression")
    }
}
