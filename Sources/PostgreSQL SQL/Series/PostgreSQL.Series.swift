internal import ISO_9075_Foundation
public import SQL
public import Time

extension PostgreSQL {
    public enum Series {}
}

extension PostgreSQL.Series {
    public static func generate(
        from start: some QueryExpression<Int>,
        through stop: some QueryExpression<Int>,
        by step: (some QueryExpression<Int>)? = Int?.none
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            "generate_series(\(([start.queryFragment, stop.queryFragment] + (step.map { [$0.queryFragment] } ?? [])).joined(separator: ", ")))",
            as: Int.self
        )
    }

    public static func generate(
        from start: some QueryExpression<Time.Instant>,
        through stop: some QueryExpression<Time.Instant>,
        every interval: String
    ) -> some QueryExpression<Time.Instant> {
        SQLQueryExpression(
            "generate_series(\(start), \(stop), \(text: interval)::interval)",
            as: Time.Instant.self
        )
    }

    public static func unnest<Source: QueryExpression>(
        _ array: Source
    ) -> some QueryExpression<Source.QueryValue.Element> where Source.QueryValue: PostgreSQL.ArrayRepresentable {
        SQLQueryExpression("unnest(\(array))", as: Source.QueryValue.Element.self)
    }

    public static func subscripts(
        of array: some QueryExpression<some PostgreSQL.ArrayRepresentable>,
        dimension: Int = 1,
        reversed isReversed: Bool = false
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            "generate_subscripts(\(array), \(raw: dimension)\(raw: isReversed ? ", TRUE" : ""))",
            as: Int.self
        )
    }
}
