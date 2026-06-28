import XCTest
@testable import DesignMD

final class FixerAndOrphanTests: XCTestCase {

    private func orphanWarnings(_ md: String) -> [String] {
        lint(md).findings
            .filter { $0.message.contains("never referenced by any component") }
            .compactMap { $0.path }
    }

    // Two distinct tokens with identical values; only one is referenced.
    // Upstream (reference-identity) flags the other as orphaned — and so must we.
    func testOrphanedDuplicateValueIsFlagged() {
        let md = """
        ---
        name: t
        colors:
          primary: "#000000"
          brandBlue: "#3366ff"
          accentBlue: "#3366ff"
        components:
          card:
            backgroundColor: "{colors.brandBlue}"
        ---
        ## Components
        """
        XCTAssertEqual(orphanWarnings(md), ["colors.accentBlue"])
    }

    // An inline literal equal to a token does NOT count as referencing that
    // token (upstream parses a fresh object); the token stays orphaned.
    func testOrphanedInlineLiteralDoesNotSuppress() {
        let md = """
        ---
        name: t
        colors:
          primary: "#000000"
          ghost: "#abcdef"
        components:
          card:
            backgroundColor: "#abcdef"
        ---
        ## Components
        """
        XCTAssertEqual(orphanWarnings(md), ["colors.ghost"])
    }

    // A genuinely referenced token is not flagged (no over-reporting).
    func testReferencedTokenNotFlagged() {
        let md = """
        ---
        name: t
        colors:
          primary: "#000000"
          accent: "#3366ff"
        components:
          card:
            backgroundColor: "{colors.accent}"
        ---
        ## Components
        """
        XCTAssertFalse(orphanWarnings(md).contains("colors.accent"))
    }

    // Alias chain: component → alias → primary marks both alias and primary.
    func testAliasChainMarksWholeChain() {
        let md = """
        ---
        name: t
        colors:
          primary: "#112233"
          brand: "{colors.primary}"
        components:
          card:
            backgroundColor: "{colors.brand}"
        ---
        ## Components
        """
        let warns = orphanWarnings(md)
        XCTAssertFalse(warns.contains("colors.brand"))
        XCTAssertFalse(warns.contains("colors.primary"))
    }

    // ── Fixer ──────────────────────────────────────────────────────

    func testFixSectionOrderReorders() {
        let md = """
        ---
        name: t
        colors: { primary: "#000000" }
        ---

        ## Colors
        body

        ## Overview
        intro
        """
        let report = lint(md)
        let result = fixSectionOrder(report.documentSections)
        XCTAssertEqual(result.details.beforeOrder, ["Colors", "Overview"])
        XCTAssertEqual(result.details.afterOrder, ["Overview", "Colors"])
        // Frontmatter (in the prelude) is preserved at the top.
        XCTAssertTrue(result.fixedContent.contains("name: t"))
        // Re-linting the fixed content no longer reports a section-order issue.
        XCTAssertFalse(lint(result.fixedContent).findings.contains {
            $0.message.contains("out of order")
        })
    }

    func testFixKeepsUnknownSectionsLast() {
        let md = """
        ---
        name: t
        colors: { primary: "#000000" }
        ---

        ## Iconography
        custom

        ## Overview
        intro
        """
        let result = fixSectionOrder(lint(md).documentSections)
        XCTAssertEqual(result.details.afterOrder, ["Overview", "Iconography"])
    }
}
