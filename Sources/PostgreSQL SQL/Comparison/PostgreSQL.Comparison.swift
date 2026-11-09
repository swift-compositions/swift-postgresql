internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum Comparison {}
}

extension PostgreSQL.Comparison {
    public static func greatest<Value>(
        _ first: some QueryExpression<Value>,
        _ second: some QueryExpression<Value>,
        _ others: any QueryExpression<Value>...
    ) -> some QueryExpression<Value> {
        SQLQueryExpression(
            "greatest(\(([first.queryFragment, second.queryFragment] + others.map(\.queryFragment)).joined(separator: ", ")))",
            as: Value.self
        )
    }

    public static func least<Value>(
        _ first: some QueryExpression<Value>,
        _ second: some QueryExpression<Value>,
        _ others: any QueryExpression<Value>...
    ) -> some QueryExpression<Value> {
        SQLQueryExpression(
            "least(\(([first.queryFragment, second.queryFragment] + others.map(\.queryFragment)).joined(separator: ", ")))",
            as: Value.self
        )
    }

    public static func numNulls<each Value: QueryExpression>(
        _ values: repeat each Value
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            "num_nulls(\(arguments(repeat each values).joined(separator: ", ")))",
            as: Int.self
        )
    }

    public static func numNonNulls<each Value: QueryExpression>(
        _ values: repeat each Value
    ) -> some QueryExpression<Int> {
        SQLQueryExpression(
            "num_nonnulls(\(arguments(repeat each values).joined(separator: ", ")))",
            as: Int.self
        )
    }

    private static func arguments<each Argument: QueryExpression>(
        _ arguments: repeat each Argument
    ) -> [ISO_9075.Fragment] {
        var fragments: [ISO_9075.Fragment] = []
        for argument in repeat each arguments {
            fragments.append(argument.queryFragment)
        }
        return fragments
    }
}
