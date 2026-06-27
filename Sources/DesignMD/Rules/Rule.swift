// Rule engine. Mirrors `linter/runner.ts` + `rules/types.ts`.

/// A finding emitted by a rule — severity is injected by the descriptor.
public struct RuleFinding {
    public var path: String?
    public var message: String
    /// Optional override of the descriptor's default severity.
    public var severity: Severity?

    public init(path: String? = nil, message: String, severity: Severity? = nil) {
        self.path = path
        self.message = message
        self.severity = severity
    }
}

public struct RuleDescriptor {
    public let name: String
    public let severity: Severity
    public let description: String
    public let run: (DesignSystemState) -> [RuleFinding]
}

public struct LintResult {
    public var findings: [Finding]
    public var summary: LintSummary
}

/// Execute each rule against the state and aggregate findings.
public func runLinter(_ state: DesignSystemState,
                      _ rules: [RuleDescriptor] = defaultRuleDescriptors) -> LintResult {
    var findings: [Finding] = []
    for desc in rules {
        for f in desc.run(state) {
            findings.append(Finding(severity: f.severity ?? desc.severity, path: f.path, message: f.message))
        }
    }
    return LintResult(
        findings: findings,
        summary: LintSummary(
            errors: findings.filter { $0.severity == .error }.count,
            warnings: findings.filter { $0.severity == .warning }.count,
            infos: findings.filter { $0.severity == .info }.count))
}

/// Levenshtein edit distance between two strings.
func levenshtein(_ a: String, _ b: String) -> Int {
    let ac = Array(a), bc = Array(b)
    let m = ac.count, n = bc.count
    if m == 0 { return n }
    if n == 0 { return m }
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 0...m { dp[i][0] = i }
    for j in 0...n { dp[0][j] = j }
    for i in 1...m {
        for j in 1...n {
            dp[i][j] = ac[i - 1] == bc[j - 1]
                ? dp[i - 1][j - 1]
                : 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
        }
    }
    return dp[m][n]
}
