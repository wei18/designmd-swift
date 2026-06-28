// Resolved value types and the fully resolved design-system model.
// Mirrors `model/spec.ts`.

public struct ResolvedColor: Equatable, Sendable {
    public let hex: String
    public let r: Int
    public let g: Int
    public let b: Int
    /// Alpha channel 0...1. nil means fully opaque (defaults to 1).
    public let a: Double?
    /// WCAG relative luminance.
    public let luminance: Double

    public init(hex: String, r: Int, g: Int, b: Int, a: Double?, luminance: Double) {
        self.hex = hex
        self.r = r
        self.g = g
        self.b = b
        self.a = a
        self.luminance = luminance
    }
}

public struct ResolvedDimension: Equatable, Sendable {
    public let value: Double
    /// The unit string. Standard units are pt/px/rem/em; others are preserved
    /// but flagged by the linter. An empty unit means a unitless multiplier.
    public let unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}

public struct ResolvedTypography: Equatable, Sendable {
    public var fontFamily: String?
    public var fontSize: ResolvedDimension?
    public var fontWeight: Double?
    public var lineHeight: ResolvedDimension?
    public var letterSpacing: ResolvedDimension?
    public var fontFeature: String?
    public var fontVariation: String?

    public init() {}
}

/// A resolved token value: a typed primitive or a raw scalar.
public enum ResolvedValue: Equatable, Sendable {
    case color(ResolvedColor)
    case dimension(ResolvedDimension)
    case typography(ResolvedTypography)
    case string(String)
    case number(Double)
    case bool(Bool)

    /// True for the three typed object kinds (objects with a `type` in TS).
    public var isTyped: Bool {
        switch self {
        case .color, .dimension, .typography: return true
        case .string, .number, .bool: return false
        }
    }

    public var asColor: ResolvedColor? {
        if case let .color(c) = self { return c }
        return nil
    }

    public var asDimension: ResolvedDimension? {
        if case let .dimension(d) = self { return d }
        return nil
    }
}

public struct ComponentDef: Equatable, Sendable {
    public var properties: OrderedDict<ResolvedValue>
    /// Unresolved references that failed to resolve.
    public var unresolvedRefs: [String]

    public init(properties: OrderedDict<ResolvedValue>, unresolvedRefs: [String]) {
        self.properties = properties
        self.unresolvedRefs = unresolvedRefs
    }
}

extension OrderedDict: Equatable where Value: Equatable {
    public static func == (lhs: OrderedDict<Value>, rhs: OrderedDict<Value>) -> Bool {
        guard lhs.keys == rhs.keys else { return false }
        for k in lhs.keys where lhs.get(k) != rhs.get(k) { return false }
        return true
    }
}

/// The fully resolved design-system state.
public struct DesignSystemState {
    public var name: String?
    public var description: String?
    public var colors = OrderedDict<ResolvedColor>()
    public var typography = OrderedDict<ResolvedTypography>()
    public var rounded = OrderedDict<ResolvedDimension>()
    public var spacing = OrderedDict<ResolvedDimension>()
    public var components = OrderedDict<ComponentDef>()
    /// Flat lookup: "colors.primary" → ResolvedValue
    public var symbolTable = OrderedDict<ResolvedValue>()
    /// Token paths reached by a component via `{token.reference}` chains (i.e.
    /// genuinely referenced, by path — the value-typed analogue of upstream's
    /// reference-identity check in the orphaned-tokens rule).
    public var referencedTokenPaths: Set<String> = []
    /// Markdown H2 heading names found in the document.
    public var sections: [String]?
    /// Top-level YAML keys not part of the known schema.
    public var unknownKeys: [String]?
    /// Raw YAML values for unknown top-level keys.
    public var unknownKeyValues: [String: YAMLValue]?

    public init() {}
}
