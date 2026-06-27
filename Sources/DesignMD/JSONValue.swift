// Minimal ordered JSON emitter matching `JSON.stringify(value, null, 2)`.

import Foundation

public indirect enum JSONValue {
    case str(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([(String, JSONValue)])

    public func serialize(level: Int = 0) -> String {
        let pad = String(repeating: "  ", count: level)
        let padIn = String(repeating: "  ", count: level + 1)
        switch self {
        case let .str(s):
            return JSONValue.escape(s)
        case let .int(n):
            return String(n)
        case let .double(d):
            if d.rounded() == d && abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        case let .bool(b):
            return b ? "true" : "false"
        case .null:
            return "null"
        case let .array(items):
            if items.isEmpty { return "[]" }
            let body = items.map { padIn + $0.serialize(level: level + 1) }.joined(separator: ",\n")
            return "[\n\(body)\n\(pad)]"
        case let .object(entries):
            if entries.isEmpty { return "{}" }
            let body = entries.map { key, value in
                padIn + JSONValue.escape(key) + ": " + value.serialize(level: level + 1)
            }.joined(separator: ",\n")
            return "{\n\(body)\n\(pad)}"
        }
    }

    private static func escape(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", Int(scalar.value))
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
        return out
    }
}
