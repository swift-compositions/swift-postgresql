internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue == String {
    public func regexpMatches(
        _ pattern: String,
        flags: String = "g"
    ) -> some QueryExpression<PostgreSQL.Array<String>> {
        SQLQueryExpression(
            "regexp_matches(\(self), \(bind: pattern), \(bind: flags))",
            as: PostgreSQL.Array<String>.self
        )
    }

    public func regexpSplitToTable(
        _ pattern: String,
        flags: String? = nil
    ) -> some QueryExpression<String> {
        SQLQueryExpression(
            "regexp_split_to_table(\(([queryFragment, pattern.queryFragment] + (flags.map { [$0.queryFragment] } ?? [])).joined(separator: ", ")))",
            as: String.self
        )
    }
}
