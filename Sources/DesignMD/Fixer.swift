// Section-order fixer. Faithful port of `fixer/handler.ts`.
// Reorders document sections into the canonical order (prelude, then known
// sections by canonical index, then unknown sections in their original order).

public struct FixerDetails: Equatable, Sendable {
    public let beforeOrder: [String]
    public let afterOrder: [String]
}

public struct FixerResult: Equatable, Sendable {
    public let fixedContent: String
    public let details: FixerDetails
}

public func fixSectionOrder(_ sections: [DocumentSection]) -> FixerResult {
    let order = SpecConfig.canonicalOrder
    func canonicalIndex(_ heading: String) -> Int? {
        order.firstIndex(of: SpecConfig.resolveAlias(heading))
    }

    let prelude = sections.first(where: { $0.heading.isEmpty })

    // Keep original index for a stable sort (JS Array.sort is stable).
    let nonEmpty = sections.enumerated().filter { !$0.element.heading.isEmpty }
    var known = nonEmpty.filter { canonicalIndex($0.element.heading) != nil }
    let unknown = nonEmpty.filter { canonicalIndex($0.element.heading) == nil }.map { $0.element }

    known.sort { a, b in
        let ia = canonicalIndex(a.element.heading)!
        let ib = canonicalIndex(b.element.heading)!
        return ia != ib ? ia < ib : a.offset < b.offset
    }

    var result: [DocumentSection] = []
    if let prelude { result.append(prelude) }
    result.append(contentsOf: known.map { $0.element })
    result.append(contentsOf: unknown)

    let fixedContent = result.map { $0.content }.joined(separator: "\n")
    let beforeOrder = sections.filter { !$0.heading.isEmpty }.map { $0.heading }
    let afterOrder = result.filter { !$0.heading.isEmpty }.map { $0.heading }

    return FixerResult(
        fixedContent: fixedContent,
        details: FixerDetails(beforeOrder: beforeOrder, afterOrder: afterOrder))
}
