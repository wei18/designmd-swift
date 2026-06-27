// OrderedDict — a minimal insertion-ordered map.
//
// The upstream TypeScript model relies on JS `Map`, which iterates in
// insertion order. Swift's `Dictionary` is unordered, so we use this to
// keep deterministic iteration (stable finding order, token summaries, etc.).

public struct OrderedDict<Value> {
    private(set) public var keys: [String] = []
    private var storage: [String: Value] = [:]

    public init() {}

    public var count: Int { keys.count }
    public var isEmpty: Bool { keys.isEmpty }
    public var size: Int { keys.count } // JS-parity alias

    public func has(_ key: String) -> Bool { storage[key] != nil }
    public func get(_ key: String) -> Value? { storage[key] }

    public mutating func set(_ key: String, _ value: Value) {
        if storage[key] == nil { keys.append(key) }
        storage[key] = value
    }

    public subscript(key: String) -> Value? {
        get { storage[key] }
        set {
            if let newValue {
                set(key, newValue)
            } else if storage[key] != nil {
                storage[key] = nil
                keys.removeAll { $0 == key }
            }
        }
    }

    /// Ordered (key, value) pairs.
    public var pairs: [(String, Value)] {
        keys.map { ($0, storage[$0]!) }
    }

    public var values: [Value] {
        keys.map { storage[$0]! }
    }
}

extension OrderedDict: Sequence {
    public func makeIterator() -> AnyIterator<(String, Value)> {
        var index = 0
        return AnyIterator {
            guard index < keys.count else { return nil }
            defer { index += 1 }
            let key = keys[index]
            return (key, storage[key]!)
        }
    }
}
