import XCTest
@testable import DesignMD

final class SpecTests: XCTestCase {

    func testSpecContentLoads() {
        let spec = specContent()
        XCTAssertTrue(spec.contains("DESIGN.md"))
        XCTAssertTrue(spec.contains("Design Tokens"))
        // The Apple pt-unit adaptation is reflected in the served spec.
        XCTAssertTrue(spec.contains("Valid units are: pt, px, em, rem"))
        XCTAssertFalse(spec.contains("(spec.md resource not found)"))
    }

    func testRulesTable() {
        let table = rulesTable()
        XCTAssertTrue(table.hasPrefix("| Rule | Severity | What it checks |\n|------|"))
        // 10 default rules → 12 lines (header + separator + 10 rows), trailing newline.
        let rows = table.split(separator: "\n")
        XCTAssertEqual(rows.count, 12)
        XCTAssertTrue(table.contains("| broken-ref | error |"))
        XCTAssertTrue(table.contains("| token-like-ignored | warning |"))
    }

    func testRuleInfos() {
        let infos = ruleInfos()
        XCTAssertEqual(infos.count, 10)
        XCTAssertEqual(infos.first?.name, "broken-ref")
        XCTAssertEqual(infos.first?.severity, "error")
        XCTAssertEqual(infos.last?.name, "token-like-ignored")
    }
}
