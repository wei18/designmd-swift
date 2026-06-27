// `spec` support — serve the DESIGN.md format spec and the active rules table.
// Mirrors `spec-gen/spec-helpers.ts`.

import Foundation

/// Rule metadata for JSON spec output.
public struct RuleInfo: Equatable, Sendable {
    public let name: String
    public let severity: String
    public let description: String
}

/// The DESIGN.md format specification document (bundled `spec.md`, Apple edition).
public func specContent() -> String {
    guard let url = Bundle.module.url(forResource: "spec", withExtension: "md", subdirectory: "Resources"),
          let text = try? String(contentsOf: url, encoding: .utf8) else {
        return "# DESIGN.md Format\n\n(spec.md resource not found)\n"
    }
    return text
}

/// Markdown table of the active lint rules.
public func rulesTable(_ rules: [RuleDescriptor] = defaultRuleDescriptors) -> String {
    var table = "| Rule | Severity | What it checks |\n"
    table += "|------|----------|----------------|\n"
    for rule in rules {
        table += "| \(rule.name) | \(rule.severity.rawValue) | \(rule.description) |\n"
    }
    return table
}

/// Structured rule metadata for JSON output.
public func ruleInfos(_ rules: [RuleDescriptor] = defaultRuleDescriptors) -> [RuleInfo] {
    rules.map { RuleInfo(name: $0.name, severity: $0.severity.rawValue, description: $0.description) }
}
