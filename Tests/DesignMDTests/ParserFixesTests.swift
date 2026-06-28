// Regression tests for divergences found in code review and fixed to match
// the upstream TypeScript behavior.

import XCTest
@testable import DesignMD

final class ParserFixesTests: XCTestCase {

    func testCRLFLineEndingsParse() {
        let crlf = "---\r\nname: t\r\ncolors:\r\n  primary: \"#000000\"\r\n---\r\n\r\n## Colors\r\n"
        let report = lint(crlf)
        XCTAssertTrue(report.designSystem.colors.has("primary"), "CRLF file should parse its frontmatter")
        XCTAssertFalse(report.findings.contains { $0.message.contains("No YAML content found") })
    }

    func testLeadingBOMStripped() {
        let bom = "\u{FEFF}---\nname: t\ncolors:\n  primary: \"#000000\"\n---\n\n## Colors\n"
        XCTAssertTrue(lint(bom).designSystem.colors.has("primary"))
    }

    func testFenceInfoStringWithMetadata() {
        let s = "# Doc\n\n```yaml title=tokens\nname: t\ncolors: { primary: \"#000000\" }\n```\n\n## Colors\n"
        XCTAssertTrue(lint(s).designSystem.colors.has("primary"), "```yaml title=x should still be recognized")
    }

    func testScientificNotationInColor() {
        // JS parseFloat("1e2") == 100 → rgb(100,0,0)
        let c = parseCssColor("rgb(1e2 0 0)")
        XCTAssertEqual(c?.r, 100)
        XCTAssertEqual(c?.hex, "#640000")
    }

    func testInfinityInColorIsInvalidLikeUpstream() {
        // parseCssColor lowercases first, so "Infinity" → "infinity" → JS
        // parseFloat("infinity") == NaN → invalid color in both TS and Swift.
        XCTAssertNil(parseCssColor("rgb(Infinity 0 0)"))
    }

    func testUnitlessLineHeightTrailingDotRejected() {
        let md = """
        ---
        name: t
        colors: { primary: "#000000" }
        typography:
          body: { fontFamily: SF Pro, fontSize: 17px, lineHeight: "5." }
        ---
        ## Typography
        """
        let report = lint(md)
        XCTAssertEqual(report.summary.errors, 1, "'5.' is not a valid dimension (matches upstream)")
        XCTAssertTrue(report.findings.contains {
            $0.severity == .error && $0.message.contains("is not a valid dimension")
        })
        XCTAssertNil(report.designSystem.typography.get("body")?.lineHeight)
    }

    func testTildeFenceParses() {
        let s = "# D\n\n~~~yaml\nname: t\ncolors: { primary: \"#000000\" }\n~~~\n\n## Colors\n"
        XCTAssertTrue(lint(s).designSystem.colors.has("primary"), "~~~yaml fences should be recognized")
    }

    func testIndentedFenceNotCaptured() {
        // 4-space indent = indented code block, not a fence (matches CommonMark/TS).
        let s = "# D\n\n    ```yaml\n    colors: { primary: \"#000000\" }\n    ```\n\n## Colors\n"
        let report = lint(s)
        XCTAssertFalse(report.designSystem.colors.has("primary"))
        XCTAssertTrue(report.findings.contains { $0.message.contains("No YAML content found") })
    }

    func testHeadingInsideFenceIsNotASection() {
        let s = """
        ---
        name: t
        colors: { primary: "#000000" }
        ---

        ## Real

        ~~~
        ## NotASection
        ~~~
        """
        let report = lint(s)
        XCTAssertTrue(report.sections.contains("Real"))
        XCTAssertFalse(report.sections.contains("NotASection"))
    }

    func testIndentedHeadingIsNotASection() {
        let s = """
        ---
        name: t
        colors: { primary: "#000000" }
        ---

        ## Real

            ## Indented
        """
        let report = lint(s)
        XCTAssertEqual(report.sections, ["Real"])
    }

    func testHeadingClosingHashesStripped() {
        let s = "---\nname: t\ncolors: { primary: \"#000000\" }\n---\n\n## Colors ##\n"
        XCTAssertTrue(lint(s).sections.contains("Colors"))
    }

    func testFrontmatterTrailingSpace() {
        let s = "--- \nname: t\ncolors: { primary: \"#000000\" }\n---\n\n## Colors\n"
        XCTAssertTrue(lint(s).designSystem.colors.has("primary"))
    }

    func testUnitlessLineHeightValidStillAccepted() {
        let md = """
        ---
        name: t
        colors: { primary: "#000000" }
        typography:
          body: { fontFamily: SF Pro, fontSize: 17px, lineHeight: "1.6" }
        ---
        ## Typography
        """
        let report = lint(md)
        XCTAssertEqual(report.designSystem.typography.get("body")?.lineHeight?.value, 1.6)
    }
}
