// Public lint entry point. Mirrors `linter/lint.ts` (minus the Tailwind config,
// which the Apple edition replaces with Swift/Asset-Catalog exporters).

import Foundation

public struct LintReport {
    /// The fully resolved design-system model.
    public var designSystem: DesignSystemState
    /// All findings (model + lint rules).
    public var findings: [Finding]
    /// Aggregate counts by severity.
    public var summary: LintSummary
    /// Markdown H2 heading names found in the document.
    public var sections: [String]
    /// The partitioned document sections.
    public var documentSections: [DocumentSection]
}

/// Lint a DESIGN.md document: parse → resolve → run rules.
public func lint(_ content: String, rules: [RuleDescriptor] = defaultRuleDescriptors) -> LintReport {
    switch DesignMarkdownParser.parse(content) {
    case let .failure(error):
        if error.recoverable {
            let model = buildModel(ParsedDesignSystem())
            let sections = extractSectionsFromContent(content)
            return LintReport(
                designSystem: model.designSystem,
                findings: [Finding(severity: .warning, message: error.message)],
                summary: LintSummary(errors: 0, warnings: 1, infos: 0),
                sections: sections.map { $0.heading }.filter { !$0.isEmpty },
                documentSections: sections)
        }
        // Non-recoverable: surface as an error finding rather than crashing.
        return LintReport(
            designSystem: buildModel(ParsedDesignSystem()).designSystem,
            findings: [Finding(severity: .error, message: "Parse failed: \(error.message)")],
            summary: LintSummary(errors: 1, warnings: 0, infos: 0),
            sections: [], documentSections: [])

    case let .success(parsed):
        let model = buildModel(parsed)
        let lintResult = runLinter(model.designSystem, rules)
        let findings = model.findings + lintResult.findings
        let summary = LintSummary(
            errors: model.findings.filter { $0.severity == .error }.count + lintResult.summary.errors,
            warnings: model.findings.filter { $0.severity == .warning }.count + lintResult.summary.warnings,
            infos: model.findings.filter { $0.severity == .info }.count + lintResult.summary.infos)
        return LintReport(
            designSystem: model.designSystem,
            findings: findings,
            summary: summary,
            sections: parsed.sections ?? [],
            documentSections: parsed.documentSections ?? [])
    }
}

/// Extract document sections from raw markdown by finding H2 headings.
/// Fallback used when the parser cannot extract YAML. Mirrors `lint.ts`.
func extractSectionsFromContent(_ content: String) -> [DocumentSection] {
    let lines = content.components(separatedBy: "\n")
    var sections: [DocumentSection] = []
    var currentStart = 0
    var currentHeading = ""
    for i in lines.indices {
        let line = lines[i]
        if line.hasPrefix("## ") {
            let heading = String(line.dropFirst(3))
            if i > 0 {
                sections.append(DocumentSection(
                    heading: currentHeading,
                    content: lines[currentStart..<i].joined(separator: "\n")))
            }
            currentHeading = heading
            currentStart = i
        }
    }
    sections.append(DocumentSection(
        heading: currentHeading,
        content: lines[currentStart...].joined(separator: "\n")))
    return sections
}
