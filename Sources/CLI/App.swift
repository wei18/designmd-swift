// designmd CLI — Apple/SwiftUI edition of the DESIGN.md tool.
// Phase 1: `lint` and `diff`. (`export`, `spec` land in later phases.)

import ArgumentParser
import DesignMD
import Foundation

@main
struct DesignMDCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "designmd",
        abstract: "Agent-first CLI for DESIGN.md — the Apple/SwiftUI edition.",
        version: "0.1.0",
        subcommands: [LintCommand.self, DiffCommand.self, ExportCommand.self, SpecCommand.self, FixCommand.self])
}

// ── lint ───────────────────────────────────────────────────────────

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Validate a DESIGN.md file for structural correctness.")

    @Argument(help: "Path to DESIGN.md (use \"-\" for stdin)")
    var file: String

    @Option(name: .long, help: "Output format: json or markdown")
    var format: String = "json"

    func run() throws {
        let content = try readInput(file)
        let report = lint(content)
        if format == "markdown" || format == "md" {
            print(lintMarkdown(report))
        } else {
            print(lintJSON(report).serialize())
        }
        if report.summary.errors > 0 { throw ExitCode(1) }
    }
}

// ── diff ───────────────────────────────────────────────────────────

struct DiffCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Compare two DESIGN.md files and report changes.")

    @Argument(help: "Path to the \"before\" DESIGN.md")
    var before: String

    @Argument(help: "Path to the \"after\" DESIGN.md")
    var after: String

    @Option(name: .long, help: "Output format: json")
    var format: String = "json"

    func run() throws {
        let beforeContent = try readInput(before)
        let afterContent = try readInput(after)
        let report = computeDiff(before: beforeContent, after: afterContent)
        print(diffJSON(report).serialize())
        if report.regression { throw ExitCode(1) }
    }
}

// ── export ─────────────────────────────────────────────────────────

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export DESIGN.md tokens. Formats: dtcg (W3C tokens.json), swift (Theme.swift), asset-catalog (.xcassets).")

    @Argument(help: "Path to DESIGN.md (use \"-\" for stdin)")
    var file: String

    @Option(name: .long, help: "Output format: dtcg, swift, asset-catalog")
    var format: String

    @Option(name: .long, help: "Output path: a file (swift) or a .xcassets directory (asset-catalog). Defaults to stdout / ./DesignTokens.xcassets.")
    var out: String?

    @Option(name: .long, help: "Top-level enum name for the swift theme (default: Theme).")
    var enumName: String = "Theme"

    static let formats = ["dtcg", "swift", "asset-catalog"]

    func run() throws {
        guard ExportCommand.formats.contains(format) else {
            let err = JSONValue.object([
                ("error", .str("Invalid format \"\(format)\". Valid formats: \(ExportCommand.formats.joined(separator: ", "))")),
            ])
            FileHandle.standardError.write(Data((err.serialize() + "\n").utf8))
            throw ExitCode(1)
        }

        let content = try readInput(file)
        let report = lint(content)

        switch format {
        case "dtcg":
            print(exportDTCG(report.designSystem).serialize())
        case "swift":
            let source = exportSwiftTheme(report.designSystem, enumName: enumName)
            if let out {
                try source.write(toFile: out, atomically: true, encoding: .utf8)
            } else {
                print(source)
            }
        case "asset-catalog":
            let dir = out ?? "DesignTokens.xcassets"
            let files = exportAssetCatalog(report.designSystem)
            try writeCatalog(files, into: dir)
            let manifest = JSONValue.object([
                ("written", .array(files.map { .str("\(dir)/\($0.path)") })),
            ])
            print(manifest.serialize())
        default:
            break
        }

        if report.summary.errors > 0 { throw ExitCode(1) }
    }

    private func writeCatalog(_ files: [GeneratedFile], into dir: String) throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: dir)
        for f in files {
            let dest = root.appendingPathComponent(f.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try f.contents.write(to: dest, atomically: true, encoding: .utf8)
        }
    }
}

// ── spec ───────────────────────────────────────────────────────────

struct SpecCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spec",
        abstract: "Output the DESIGN.md format specification (handy for agent prompts).")

    @Flag(name: .long, help: "Append the active linting rules table.")
    var rules = false

    @Flag(name: .long, help: "Output only the active linting rules table.")
    var rulesOnly = false

    @Option(name: .long, help: "Output format: markdown or json")
    var format: String = "markdown"

    func run() throws {
        if format == "json" {
            var fields: [(String, JSONValue)] = []
            if rulesOnly {
                fields.append(("rules", rulesArray()))
            } else {
                fields.append(("spec", .str(specContent())))
                if rules { fields.append(("rules", rulesArray())) }
            }
            print(JSONValue.object(fields).serialize())
            return
        }

        if rulesOnly {
            print(rulesTable())
            return
        }

        var output = specContent()
        if rules {
            output += "\n\n## Active Linting Rules\n\n" + rulesTable()
        }
        print(output)
    }

    private func rulesArray() -> JSONValue {
        .array(ruleInfos().map { info in
            .object([
                ("name", .str(info.name)),
                ("severity", .str(info.severity)),
                ("description", .str(info.description)),
            ])
        })
    }
}

// ── fix ────────────────────────────────────────────────────────────

struct FixCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fix",
        abstract: "Reorder a DESIGN.md's sections into the canonical order.")

    @Argument(help: "Path to DESIGN.md (use \"-\" for stdin)")
    var file: String

    @Flag(name: .long, help: "Write the fixed content back to the file in place.")
    var write = false

    @Option(name: .long, help: "Output format: text (fixed content) or json (details).")
    var format: String = "text"

    func run() throws {
        let content = try readInput(file)
        let report = lint(content)
        let result = fixSectionOrder(report.documentSections)

        if write {
            guard file != "-" else {
                FileHandle.standardError.write(Data("cannot --write when reading from stdin\n".utf8))
                throw ExitCode(2)
            }
            try result.fixedContent.write(toFile: file, atomically: true, encoding: .utf8)
            return
        }

        if format == "json" {
            print(JSONValue.object([
                ("details", .object([
                    ("beforeOrder", .array(result.details.beforeOrder.map { .str($0) })),
                    ("afterOrder", .array(result.details.afterOrder.map { .str($0) })),
                ])),
                ("fixedContent", .str(result.fixedContent)),
            ]).serialize())
        } else {
            print(result.fixedContent)
        }
    }
}

// ── Input ──────────────────────────────────────────────────────────

func readInput(_ path: String) throws -> String {
    if path == "-" {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
    do {
        return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        let err = JSONValue.object([
            ("error", .str("FILE_READ_ERROR")),
            ("message", .str(error.localizedDescription)),
            ("path", .str(path)),
        ])
        FileHandle.standardError.write(Data((err.serialize() + "\n").utf8))
        throw ExitCode(2)
    }
}

// ── Output shapes ──────────────────────────────────────────────────

func lintJSON(_ report: LintReport) -> JSONValue {
    let findings: [JSONValue] = report.findings.map { f in
        var fields: [(String, JSONValue)] = [("severity", .str(f.severity.rawValue))]
        if let p = f.path { fields.append(("path", .str(p))) }
        fields.append(("message", .str(f.message)))
        return .object(fields)
    }
    return .object([
        ("findings", .array(findings)),
        ("summary", summaryJSON(report.summary)),
    ])
}

func summaryJSON(_ s: LintSummary) -> JSONValue {
    .object([("errors", .int(s.errors)), ("warnings", .int(s.warnings)), ("infos", .int(s.infos))])
}

func mapDiffJSON(_ d: MapDiff) -> JSONValue {
    .object([
        ("added", .array(d.added.map { .str($0) })),
        ("removed", .array(d.removed.map { .str($0) })),
        ("modified", .array(d.modified.map { .str($0) })),
    ])
}

func diffJSON(_ r: DiffReport) -> JSONValue {
    .object([
        ("tokens", .object([
            ("colors", mapDiffJSON(r.tokens.colors)),
            ("typography", mapDiffJSON(r.tokens.typography)),
            ("rounded", mapDiffJSON(r.tokens.rounded)),
            ("spacing", mapDiffJSON(r.tokens.spacing)),
            ("components", mapDiffJSON(r.tokens.components)),
        ])),
        ("findings", .object([
            ("before", summaryJSON(r.findings.before)),
            ("after", summaryJSON(r.findings.after)),
            ("delta", .object([
                ("errors", .int(r.findings.deltaErrors)),
                ("warnings", .int(r.findings.deltaWarnings)),
            ])),
        ])),
        ("regression", .bool(r.regression)),
    ])
}

func lintMarkdown(_ report: LintReport) -> String {
    var out = "# Lint Report\n\n"
    out += "**\(report.summary.errors) errors**, **\(report.summary.warnings) warnings**, **\(report.summary.infos) infos**\n"
    if !report.findings.isEmpty {
        out += "\n## Findings\n\n"
        for f in report.findings {
            let location = f.path.map { " `\($0)`:" } ?? ":"
            out += "- **\(f.severity.rawValue)**\(location) \(f.message)\n"
        }
    }
    return out
}
