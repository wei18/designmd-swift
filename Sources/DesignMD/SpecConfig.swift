// SpecConfig — the single source of truth for the DESIGN.md format.
//
// Mirrors `spec-config.yaml` from the upstream TypeScript project
// (google-labs-code/design.md). Transcribed into Swift constants so the
// package needs no resource bundle and stays cross-platform.
//
// APPLE ADAPTATION: `pt` (points) is added as a first-class standard unit
// alongside px/rem/em, so design systems authored for UIKit/SwiftUI are not
// flagged as using an invalid unit. Everything else matches upstream.

import Foundation

public enum SpecConfig {
    /// Current spec version.
    public static let version = "alpha"

    // Performance and safety limits for the model handler.
    public static let maxTokenNestingDepth = 20
    public static let maxReferenceDepth = 10

    /// Units the spec formally supports for Dimension values.
    /// `pt` is the Apple addition; px/rem/em kept for upstream compatibility.
    public static let standardUnits: [String] = ["pt", "px", "rem", "em"]

    public struct SectionDef {
        public let canonical: String
        public let aliases: [String]
        public init(_ canonical: String, aliases: [String] = []) {
            self.canonical = canonical
            self.aliases = aliases
        }
    }

    public static let sections: [SectionDef] = [
        SectionDef("Overview", aliases: ["Brand & Style"]),
        SectionDef("Colors"),
        SectionDef("Typography"),
        SectionDef("Layout", aliases: ["Layout & Spacing"]),
        SectionDef("Elevation & Depth", aliases: ["Elevation"]),
        SectionDef("Shapes"),
        SectionDef("Components"),
        SectionDef("Do's and Don'ts"),
    ]

    /// Ordered list of canonical section names.
    public static let canonicalOrder: [String] = sections.map { $0.canonical }

    /// Map of alias → canonical name.
    public static let sectionAliases: [String: String] = {
        var map: [String: String] = [:]
        for s in sections {
            for alias in s.aliases { map[alias] = s.canonical }
        }
        return map
    }()

    /// Resolve a section heading to its canonical name.
    public static func resolveAlias(_ heading: String) -> String {
        sectionAliases[heading] ?? heading
    }

    public static let validTypographyProps: [String] = [
        "fontFamily", "fontSize", "fontWeight", "lineHeight",
        "letterSpacing", "fontFeature", "fontVariation",
    ]

    public static let validComponentSubTokens: [String] = [
        "backgroundColor", "textColor", "typography", "rounded",
        "padding", "size", "height", "width",
    ]

    public static let coreColorRoles: [String] = ["primary", "secondary", "tertiary", "neutral"]

    public static let recommendedTokens: [String: [String]] = [
        "colors": ["primary", "secondary", "tertiary", "neutral", "surface", "on-surface", "error"],
        "typography": [
            "headline-display", "headline-lg", "headline-md",
            "body-lg", "body-md", "body-sm",
            "label-lg", "label-md", "label-sm",
        ],
        "rounded": ["none", "sm", "md", "lg", "xl", "full"],
    ]

    /// Canonical top-level YAML keys per the DESIGN.md schema.
    public static let schemaKeys: [String] = [
        "version", "name", "description", "colors",
        "typography", "rounded", "spacing", "components",
    ]
}
