// Golden parity tests: the library `lint()` must reproduce the exact findings
// and summary captured from the upstream TypeScript CLI (verified identical),
// except `apple-points.md` which exercises the intentional pt-unit adaptation.

import XCTest
import Foundation
@testable import DesignMD

final class LintParityTests: XCTestCase {

    private struct GoldenFinding {
        let severity: String
        let path: String?
        let message: String
    }
    private struct Golden {
        let findings: [GoldenFinding]
        let errors: Int
        let warnings: Int
        let infos: Int
    }

    func testAllFixturesMatchGolden() throws {
        let fixtures = try mdFixtureURLs()
        XCTAssertGreaterThanOrEqual(fixtures.count, 10, "expected the fixture corpus to be present")

        for url in fixtures {
            let name = url.deletingPathExtension().lastPathComponent
            let content = try String(contentsOf: url, encoding: .utf8)
            let report = lint(content)

            let golden = try loadGolden(forFixture: url)
            XCTAssertEqual(report.summary.errors, golden.errors, "[\(name)] errors")
            XCTAssertEqual(report.summary.warnings, golden.warnings, "[\(name)] warnings")
            XCTAssertEqual(report.summary.infos, golden.infos, "[\(name)] infos")
            XCTAssertEqual(report.findings.count, golden.findings.count, "[\(name)] finding count")

            for (i, f) in report.findings.enumerated() where i < golden.findings.count {
                let g = golden.findings[i]
                XCTAssertEqual(f.severity.rawValue, g.severity, "[\(name)] #\(i) severity")
                XCTAssertEqual(f.path, g.path, "[\(name)] #\(i) path")
                XCTAssertEqual(f.message, g.message, "[\(name)] #\(i) message")
            }
        }
    }

    /// The pt-unit Apple adaptation: pt is accepted (no invalid-unit errors).
    func testApplePointsHasNoUnitErrors() throws {
        let url = try fixtureURL("apple-points", ext: "md")
        let report = lint(try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(report.summary.errors, 0, "pt should be a valid unit in the Apple edition")
        XCTAssertFalse(report.findings.contains { $0.message.contains("invalid unit 'pt'") })
    }

    // ── Helpers ────────────────────────────────────────────────────

    private func mdFixtureURLs() throws -> [URL] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "md", subdirectory: "Fixtures") ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fixtureURL(_ name: String, ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            throw XCTSkip("missing fixture \(name).\(ext)")
        }
        return url
    }

    private func loadGolden(forFixture md: URL) throws -> Golden {
        let goldenURL = md.deletingPathExtension().appendingPathExtension("lint.golden.json")
        let data = try Data(contentsOf: goldenURL)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let rawFindings = obj["findings"] as! [[String: Any]]
        let summary = obj["summary"] as! [String: Any]
        let findings = rawFindings.map {
            GoldenFinding(severity: $0["severity"] as! String,
                          path: $0["path"] as? String,
                          message: $0["message"] as! String)
        }
        return Golden(findings: findings,
                      errors: summary["errors"] as! Int,
                      warnings: summary["warnings"] as! Int,
                      infos: summary["infos"] as! Int)
    }
}
