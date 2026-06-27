// Finding — a diagnostic produced by the model or a lint rule.

public enum Severity: String, Codable, Equatable, Sendable {
    case error
    case warning
    case info
}

public struct Finding: Equatable, Sendable {
    public var severity: Severity
    public var path: String?
    public var message: String

    public init(severity: Severity, path: String? = nil, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

/// Aggregate counts by severity.
public struct LintSummary: Equatable, Sendable {
    public var errors: Int
    public var warnings: Int
    public var infos: Int

    public init(errors: Int, warnings: Int, infos: Int) {
        self.errors = errors
        self.warnings = warnings
        self.infos = infos
    }
}
