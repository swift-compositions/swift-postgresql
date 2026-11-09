internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue == String {
    public func ilike(
        _ pattern: some StringProtocol,
        escape: Character? = nil
    ) -> some QueryExpression<Bool> {
        matching("ILIKE", pattern, escape: escape)
    }

    public func similarTo(
        _ pattern: some StringProtocol,
        escape: Character? = nil
    ) -> some QueryExpression<Bool> {
        matching("SIMILAR TO", pattern, escape: escape)
    }

    public func notSimilarTo(
        _ pattern: some StringProtocol,
        escape: Character? = nil
    ) -> some QueryExpression<Bool> {
        matching("NOT SIMILAR TO", pattern, escape: escape)
    }

    public func regexMatch(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        matching("~", pattern)
    }

    public func regexMatchCaseInsensitive(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        matching("~*", pattern)
    }

    public func regexNotMatch(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        matching("!~", pattern)
    }

    public func regexNotMatchCaseInsensitive(_ pattern: some StringProtocol) -> some QueryExpression<Bool> {
        matching("!~*", pattern)
    }

    public func regexpLike(
        _ pattern: some StringProtocol,
        flags: String? = nil
    ) -> some QueryExpression<Bool> {
        SQLQueryExpression(
            regexp("regexp_like", [String(pattern).queryFragment], [flags?.queryFragment], defaults: [""]),
            as: Bool.self
        )
    }

    public func regexpCount(
        _ pattern: some StringProtocol,
        start: Int? = nil,
        flags: String? = nil
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            regexp(
                "regexp_count",
                [String(pattern).queryFragment],
                [start.map { ISO_9075.Fragment("\(raw: $0)") }, flags?.queryFragment],
                defaults: ["1", ""]
            ),
            as: Int.self
        )
    }

    public func regexpInstr(
        _ pattern: some StringProtocol,
        start: Int? = nil,
        occurrence: Int? = nil,
        flags: String? = nil
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            regexp(
                "regexp_instr",
                [String(pattern).queryFragment],
                [
                    start.map { ISO_9075.Fragment("\(raw: $0)") },
                    occurrence.map { ISO_9075.Fragment("\(raw: $0)") },
                    nil,
                    flags?.queryFragment,
                ],
                defaults: ["1", "1", "0", ""]
            ),
            as: Int.self
        )
    }

    public func regexpReplace(
        _ pattern: some StringProtocol,
        _ replacement: some StringProtocol,
        start: Int? = nil,
        occurrence: Int? = nil,
        flags: String? = nil
    ) -> some QueryExpression<String> {
        SQLQueryExpression(
            regexp(
                "regexp_replace",
                [String(pattern).queryFragment, String(replacement).queryFragment],
                start == nil && occurrence == nil
                    ? [flags?.queryFragment]
                    : [
                        start.map { ISO_9075.Fragment("\(raw: $0)") },
                        occurrence.map { ISO_9075.Fragment("\(raw: $0)") },
                        flags?.queryFragment,
                    ],
                defaults: ["1", flags?.contains("g") == true ? "0" : "1", ""]
            ),
            as: String.self
        )
    }

    public func regexpSubstr(
        _ pattern: some StringProtocol,
        start: Int? = nil,
        occurrence: Int? = nil,
        flags: String? = nil
    ) -> some QueryExpression<String?> {
        SQLQueryExpression(
            regexp(
                "regexp_substr",
                [String(pattern).queryFragment],
                [
                    start.map { ISO_9075.Fragment("\(raw: $0)") },
                    occurrence.map { ISO_9075.Fragment("\(raw: $0)") },
                    flags?.queryFragment,
                ],
                defaults: ["1", "1", ""]
            ),
            as: String?.self
        )
    }

    private func matching(
        _ operator: String,
        _ pattern: some StringProtocol,
        escape: Character? = nil
    ) -> SQLQueryExpression<Bool> {
        let clause: ISO_9075.Fragment = escape.map { " ESCAPE \(bind: String($0))" } ?? ""
        return SQLQueryExpression(
            "(\(self) \(raw: `operator`) \(bind: String(pattern))\(clause))",
            as: Bool.self
        )
    }

    private func regexp(
        _ name: String,
        _ arguments: [ISO_9075.Fragment],
        _ options: [ISO_9075.Fragment?],
        defaults: [ISO_9075.Fragment]
    ) -> ISO_9075.Fragment {
        "\(raw: name)(\(([queryFragment] + arguments + options.positional(defaults: defaults)).joined(separator: ", ")))"
    }
}

extension [ISO_9075.Fragment?] {
    fileprivate func positional(defaults: [ISO_9075.Fragment]) -> [ISO_9075.Fragment] {
        zip(self, defaults).prefix((lastIndex { $0 != nil } ?? -1) + 1).map { $0 ?? $1 }
    }
}
