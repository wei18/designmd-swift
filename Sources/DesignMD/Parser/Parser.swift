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

        // ── Frontmatter (only at the very top) ──
        var i = 0
        if !lines.isEmpty && lines[0] == "---" {
            var j = 1
            var body: [String] = []
            while j < lines.count && lines[j] != "---" {
                body.append(lines[j]); j += 1
            }
            if j < lines.count {  // found closing ---
                blocks.append(Block(yaml: body.joined(separator: "\n"),
                                    codeBlockIndex: nil, startLine: 1))
                i = j + 1
            }
        }

        // ── Scan remaining lines for fenced yaml blocks and H2 headings ──
        var codeBlockIndex = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let fenceLang = fenceInfo(trimmed) {
                // opening fence at line i (1-based: i+1)
                let startLine = i + 1
                var body: [String] = []
                var k = i + 1
                while k < lines.count && !isFenceClose(lines[k]) {
                    body.append(lines[k]); k += 1
                }
                if fenceLang == "yaml" || fenceLang == "yml" {
                    blocks.append(Block(yaml: body.joined(separator: "\n"),
                                        codeBlockIndex: codeBlockIndex, startLine: startLine))
                    codeBlockIndex += 1
                }
                i = k + 1  // skip past closing fence
                continue
            }
            if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { headings.append((text, i + 1)) }
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

    private static func fenceInfo(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("```") else { return nil }
        let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        // The language is the first token of the info string; ignore trailing
        // metadata like ```yaml title=x (mirrors CommonMark's lang/meta split).
        let lang = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return lang.lowercased()  // "" for a bare fence, otherwise the language
    }

    private static func isFenceClose(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
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
