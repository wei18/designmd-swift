// YAMLValue — an ordered, typed representation of parsed YAML.
//
// JS `YAML.parse` yields native types (number/bool/string) and preserves
// object insertion order. Swift dictionaries lose order and Yams scalars are
// stringly-typed, so we build this from Yams `Node` to keep both order and
// the number/bool/string distinction the model relies on.

import Foundation
import Yams

public indirect enum YAMLValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([YAMLValue])
    case mapping([Entry])

    public struct Entry: Equatable, Sendable {
        public let key: String
        public let value: YAMLValue
        public init(key: String, value: YAMLValue) {
            self.key = key
            self.value = value
        }
    }

    // ── Accessors ──────────────────────────────────────────────────

    /// Ordered entries when this is a mapping.
    public var entries: [Entry]? {
        if case let .mapping(e) = self { return e }
        return nil
    }

    public var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    public var isObject: Bool {
        if case .mapping = self { return true }
        return false
    }

    public subscript(_ key: String) -> YAMLValue? {
        entries?.first(where: { $0.key == key })?.value
    }

    /// The natural textual form used in finding messages (JS `${value}`).
    public var display: String {
        switch self {
        case let .string(s): return s
        case let .number(n): return YAMLValue.formatNumber(n)
        case let .bool(b): return b ? "true" : "false"
        case .null: return "null"
        case .array, .mapping: return ""
        }
    }

    static func formatNumber(_ n: Double) -> String {
        if n.rounded() == n && abs(n) < 1e15 {
            return String(Int(n))
        }
        return String(n)
    }

    // ── Build from Yams ────────────────────────────────────────────

    public static func from(node: Node) -> YAMLValue {
        switch node {
        case let .scalar(scalar):
            return fromScalar(scalar)
        case let .mapping(mapping):
            var entries: [Entry] = []
            for (keyNode, valueNode) in mapping {
                let key = keyNode.string ?? String(describing: keyNode)
                entries.append(Entry(key: key, value: from(node: valueNode)))
            }
            return .mapping(entries)
        case let .sequence(sequence):
            return .array(sequence.map { from(node: $0) })
        case .alias:
            return .null
        }
    }

    private static func fromScalar(_ scalar: Node.Scalar) -> YAMLValue {
        // Quoted scalars are always strings, regardless of content.
        if scalar.style == .singleQuoted || scalar.style == .doubleQuoted {
            return .string(scalar.string)
        }
        return resolvePlain(scalar.string)
    }

    /// Resolve a plain (unquoted) YAML scalar per the YAML 1.2 core schema,
    /// matching the `yaml` npm package the upstream project uses.
    private static func resolvePlain(_ s: String) -> YAMLValue {
        switch s {
        case "", "~", "null", "Null", "NULL": return .null
        case "true", "True", "TRUE": return .bool(true)
        case "false", "False", "FALSE": return .bool(false)
        default:
            if let first = s.first, "+-.0123456789".contains(first) {
                if let i = Int(s) { return .number(Double(i)) }
                if let d = Double(s) { return .number(d) }
            }
            return .string(s)
        }
    }
}
