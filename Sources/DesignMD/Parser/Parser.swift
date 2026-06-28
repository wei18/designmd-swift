// Parser — extracts YAML design tokens and section structure from DESIGN.md.
// Mirrors `parser/handler.ts`. Supports frontmatter (---) and fenced yaml blocks.

import Foundation
import Yams

public enum ParserErrorCode: String, Sendable {
    case emptyContent = "EMPTY_CONTENT"
    case noYamlFound = "NO_YAML_FOUND"
    case yamlParseError = "YAML_PARSE_ERROR"
    case duplicateSection = "DUPLICATE_SECTION"
    case unknownError = "UNKNOWN_ERROR"
}

public struct ParserError: Sendable {
    public let code: ParserErrorCode
    public let message: String
    public let recoverable: Bool
}

public struct DocumentSection: Equatable, Sendable {
    public let heading: String
    public let content: String
}

/// Raw, unresolved parsed output — mirrors the YAML schema.
public struct ParsedDesignSystem {
    public var version: String?
    public var name: String?
    public var description: String?
    public var colors: YAMLValue?
    public var typography: YAMLValue?
    public var rounded: YAMLValue?
    public var spacing: YAMLValue?
    public var components: YAMLValue?
    /// Ordered top-level YAML keys (for unknown-key detection).
    public var topLevelKeys: [String] = []
    public var sections: [String]?
    public var documentSections: [DocumentSection]?
    /// Raw YAML values for all top-level keys, used by lint rules.
    public var rawValues: [String: YAMLValue] = [:]

    public init() {}
}

public enum ParserResult {
    case success(ParsedDesignSystem)
    case failure(ParserError)
}

public enum DesignMarkdownParser {
    private struct Block {
        let yaml: String
        /// nil = frontmatter, otherwise 0-based code-block index.
        let codeBlockIndex: Int?
        let startLine: Int
    }

    public static func parse(_ rawContent: String) -> ParserResult {
        // Normalize line endings (CRLF / CR → LF) and strip a leading BOM, so
        // Windows / git-autocrlf authored files parse identically to LF files.
        var content = rawContent
        if content.hasPrefix("\u{FEFF}") { content.removeFirst() }
        content = content.replacingOccurrences(of: "\r\n", with: "\n")
                         .replacingOccurrences(of: "\r", with: "\n")
        let lines = content.components(separatedBy: "\n")
        var blocks: [Block] = []
        var headings: [(text: String, line: Int)] = []  // 1-based

        // ── Frontmatter (only at the very top; fences may carry trailing space) ──
        var i = 0
        if let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" {
            var j = 1
            var body: [String] = []
            while j < lines.count && lines[j].trimmingCharacters(in: .whitespaces) != "---" {
                body.append(lines[j]); j += 1
            }
            if j < lines.count {  // found closing ---
                blocks.append(Block(yaml: body.joined(separator: "\n"),
                                    codeBlockIndex: nil, startLine: 1))
                i = j + 1
            }
        }

        // ── Scan remaining lines for fenced yaml blocks and H2 headings ──
        // CommonMark-aligned: fences/headings may be indented up to 3 spaces;
        // 4+ spaces is an indented code block. ``` and ~~~ fences both supported.
        var codeBlockIndex = 0
        while i < lines.count {
            let line = lines[i]
            if let open = fenceOpen(line) {
                let startLine = i + 1
                var body: [String] = []
                var k = i + 1
                while k < lines.count && !isFenceClose(lines[k], char: open.char, len: open.len) {
                    body.append(lines[k]); k += 1
                }
                if open.lang == "yaml" || open.lang == "yml" {
                    blocks.append(Block(yaml: body.joined(separator: "\n"),
                                        codeBlockIndex: codeBlockIndex, startLine: startLine))
                    codeBlockIndex += 1
                }
                i = k < lines.count ? k + 1 : k  // skip past closing fence if present
                continue
            }
            if let text = atxHeading2(line), !text.isEmpty {
                headings.append((text, i + 1))
            }
            i += 1
        }

        let sections = headings.map { $0.text }
        let documentSections = sliceSections(lines: lines, headings: headings, content: content)

        if blocks.isEmpty {
            return .failure(ParserError(
                code: .noYamlFound,
                message: "No YAML content found. Expected frontmatter (---) or fenced yaml code blocks.",
                recoverable: true))
        }

        return mergeBlocks(blocks, sections: sections, documentSections: documentSections)
    }

    /// Count leading spaces (≤3 of which are allowed indentation) and the rest.
    private static func leadingIndent(_ line: String) -> (indent: Int, rest: Substring) {
        var n = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == " " { n += 1; idx = line.index(after: idx) }
        return (n, line[idx...])
    }

    /// If `line` opens a fenced code block (≤3 indent, 3+ ``` or ~~~), return the
    /// fence char, its length, and the lowercased language (first info token).
    private static func fenceOpen(_ line: String) -> (char: Character, len: Int, lang: String)? {
        let (indent, rest) = leadingIndent(line)
        guard indent <= 3, let first = rest.first, first == "`" || first == "~" else { return nil }
        var len = 0
        for c in rest { if c == first { len += 1 } else { break } }
        guard len >= 3 else { return nil }
        let info = String(rest.dropFirst(len)).trimmingCharacters(in: .whitespaces)
        // A backtick fence's info string may not contain a backtick (CommonMark).
        if first == "`", info.contains("`") { return nil }
        let lang = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)?.lowercased() ?? ""
        return (first, len, lang)
    }

    /// A closing fence: same char, length ≥ opening, ≤3 indent, only whitespace after.
    private static func isFenceClose(_ line: String, char: Character, len: Int) -> Bool {
        let (indent, rest) = leadingIndent(line)
        guard indent <= 3 else { return false }
        var n = 0
        var idx = rest.startIndex
        while idx < rest.endIndex, rest[idx] == char { n += 1; idx = rest.index(after: idx) }
        guard n >= len else { return false }
        return rest[idx...].allSatisfy { $0.isWhitespace }
    }

    /// Extract the text of an ATX H2 (`## …`, ≤3 indent), or nil. Strips an
    /// optional closing `#` sequence (`## Colors ##` → `Colors`).
    private static func atxHeading2(_ line: String) -> String? {
        let (indent, rest) = leadingIndent(line)
        guard indent <= 3 else { return nil }
        guard rest.hasPrefix("## ") || rest == "##" else { return nil }
        var text = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        if let r = text.range(of: " #", options: .backwards) {
            let tail = text[r.lowerBound...].trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty, tail.allSatisfy({ $0 == "#" }) {
                text = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return text
    }

    private static func sliceSections(lines: [String], headings: [(text: String, line: Int)],
                                      content: String) -> [DocumentSection] {
        var result: [DocumentSection] = []
        guard let first = headings.first else {
            return [DocumentSection(heading: "", content: content)]
        }
        if first.line > 1 {
            result.append(DocumentSection(
                heading: "",
                content: lines[0..<(first.line - 1)].joined(separator: "\n")))
        }
        for idx in headings.indices {
            let current = headings[idx]
            let startIdx = current.line - 1
            let endIdx = idx + 1 < headings.count ? headings[idx + 1].line - 1 : lines.count
            result.append(DocumentSection(
                heading: current.text,
                content: lines[startIdx..<endIdx].joined(separator: "\n")))
        }
        return result
    }

    private static func mergeBlocks(_ blocks: [Block], sections: [String],
                                    documentSections: [DocumentSection]) -> ParserResult {
        var merged: [String: YAMLValue] = [:]
        var order: [String] = []
        var seen: [String: Int?] = [:]  // key → block id

        for block in blocks {
            let node: Node?
            do {
                node = try Yams.compose(yaml: block.yaml)
            } catch {
                return .failure(ParserError(code: .yamlParseError,
                                            message: "\(error)", recoverable: true))
            }
            guard let node, case .mapping = node else { continue }
            let value = YAMLValue.from(node: node)
            guard let entries = value.entries else { continue }

            for entry in entries {
                if let prev = seen[entry.key] {
                    let prevDesc = describeBlock(prev)
                    let currDesc = describeBlock(block.codeBlockIndex)
                    return .failure(ParserError(
                        code: .duplicateSection,
                        message: "Section '\(entry.key)' is defined in both \(prevDesc) and \(currDesc).",
                        recoverable: true))
                }
                seen[entry.key] = block.codeBlockIndex
                if merged[entry.key] == nil { order.append(entry.key) }
                merged[entry.key] = entry.value
            }
        }

        var ds = ParsedDesignSystem()
        ds.rawValues = merged
        ds.topLevelKeys = order
        ds.sections = sections
        ds.documentSections = documentSections
        ds.version = merged["version"]?.stringValue
        ds.name = merged["name"]?.stringValue
        ds.description = merged["description"]?.stringValue
        ds.colors = merged["colors"]?.isObject == true ? merged["colors"] : nil
        ds.typography = merged["typography"]?.isObject == true ? merged["typography"] : nil
        ds.rounded = merged["rounded"]?.isObject == true ? merged["rounded"] : nil
        ds.spacing = merged["spacing"]?.isObject == true ? merged["spacing"] : nil
        ds.components = merged["components"]?.isObject == true ? merged["components"] : nil
        return .success(ds)
    }

    private static func describeBlock(_ id: Int?) -> String {
        guard let id else { return "frontmatter" }
        return "code block \(id + 1)"
    }
}
