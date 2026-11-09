internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: QueryBindable {
    public func lag(
        offset: Int = 1,
        default defaultValue: QueryValue? = nil
    ) -> PostgreSQL.Window.Function<QueryValue._Optionalized> {
        PostgreSQL.Window.Function("lag", shifted(by: offset, default: defaultValue))
    }

    public func lead(
        offset: Int = 1,
        default defaultValue: QueryValue? = nil
    ) -> PostgreSQL.Window.Function<QueryValue._Optionalized> {
        PostgreSQL.Window.Function("lead", shifted(by: offset, default: defaultValue))
    }

    public func firstValue() -> PostgreSQL.Window.Function<QueryValue> {
        PostgreSQL.Window.Function("first_value", [queryFragment])
    }

    public func lastValue() -> PostgreSQL.Window.Function<QueryValue> {
        PostgreSQL.Window.Function("last_value", [queryFragment])
    }

    public func nthValue(_ position: Int) -> PostgreSQL.Window.Function<QueryValue._Optionalized> {
        precondition(position > 0, "nth_value position must be positive (1-indexed)")
        return PostgreSQL.Window.Function("nth_value", [queryFragment, "\(raw: position)"])
    }

    private func shifted(by offset: Int, default defaultValue: QueryValue?) -> [ISO_9075.Fragment] {
        precondition(offset >= 0, "a window offset must not be negative, got \(offset)")
        return [queryFragment, "\(raw: offset)"] + (defaultValue.map { [$0.queryFragment] } ?? [])
    }
}
