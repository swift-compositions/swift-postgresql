internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: PostgreSQL.ArrayRepresentable {
    public func contains<Other: QueryExpression>(_ other: Other) -> some QueryExpression<Bool>
    where Other.QueryValue: PostgreSQL.ArrayRepresentable, Other.QueryValue.Element == QueryValue.Element {
        SQLQueryExpression("(\(self) @> \(other))", as: Bool.self)
    }

    public func isContained<Other: QueryExpression>(by other: Other) -> some QueryExpression<Bool>
    where Other.QueryValue: PostgreSQL.ArrayRepresentable, Other.QueryValue.Element == QueryValue.Element {
        SQLQueryExpression("(\(self) <@ \(other))", as: Bool.self)
    }

    public func overlaps<Other: QueryExpression>(_ other: Other) -> some QueryExpression<Bool>
    where Other.QueryValue: PostgreSQL.ArrayRepresentable, Other.QueryValue.Element == QueryValue.Element {
        SQLQueryExpression("(\(self) && \(other))", as: Bool.self)
    }

    public func concatenated<Other: QueryExpression>(with other: Other) -> some QueryExpression<QueryValue>
    where Other.QueryValue: PostgreSQL.ArrayRepresentable, Other.QueryValue.Element == QueryValue.Element {
        SQLQueryExpression("(\(self) || \(other))", as: QueryValue.self)
    }

    public func appending(_ element: some QueryExpression<QueryValue.Element>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("array_append(\(self), \(element))", as: QueryValue.self)
    }

    public func prepending(_ element: some QueryExpression<QueryValue.Element>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("array_prepend(\(element), \(self))", as: QueryValue.self)
    }

    public func removing(_ element: some QueryExpression<QueryValue.Element>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("array_remove(\(self), \(element))", as: QueryValue.self)
    }

    public func replacing(
        _ element: some QueryExpression<QueryValue.Element>,
        with replacement: some QueryExpression<QueryValue.Element>
    ) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("array_replace(\(self), \(element), \(replacement))", as: QueryValue.self)
    }

    public func position(
        of element: some QueryExpression<QueryValue.Element>,
        from start: Int? = nil
    ) -> some QueryExpression<Int?> {
        let start: ISO_9075.Fragment = start.map { ", \(raw: $0)" } ?? ""
        return SQLQueryExpression("array_position(\(self), \(element)\(start))", as: Int?.self)
    }

    public func positions(
        of element: some QueryExpression<QueryValue.Element>
    ) -> some QueryExpression<PostgreSQL.Array<Int>?> {
        SQLQueryExpression("array_positions(\(self), \(element))", as: PostgreSQL.Array<Int>?.self)
    }

    public func element(at index: Int) -> some QueryExpression<QueryValue.Element._Optionalized> {
        SQLQueryExpression("(\(self))[\(raw: index)]", as: QueryValue.Element._Optionalized.self)
    }

    public func slice(_ indices: ClosedRange<Int>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self))[\(raw: indices.lowerBound):\(raw: indices.upperBound)]", as: QueryValue.self)
    }

    public func cardinality() -> some QueryExpression<Int?> {
        SQLQueryExpression("cardinality(\(self))", as: Int?.self)
    }

    public func length(dimension: Int = 1) -> some QueryExpression<Int?> {
        SQLQueryExpression("array_length(\(self), \(raw: dimension))", as: Int?.self)
    }

    public func lowerBound(dimension: Int = 1) -> some QueryExpression<Int?> {
        SQLQueryExpression("array_lower(\(self), \(raw: dimension))", as: Int?.self)
    }

    public func upperBound(dimension: Int = 1) -> some QueryExpression<Int?> {
        SQLQueryExpression("array_upper(\(self), \(raw: dimension))", as: Int?.self)
    }

    public func dimensionCount() -> some QueryExpression<Int?> {
        SQLQueryExpression("array_ndims(\(self))", as: Int?.self)
    }

    public func dimensions() -> some QueryExpression<String?> {
        SQLQueryExpression("array_dims(\(self))", as: String?.self)
    }

    public func arrayToString(separator: String, null: String? = nil) -> some QueryExpression<String?> {
        let null: ISO_9075.Fragment = null.map { ", \(bind: $0)" } ?? ""
        return SQLQueryExpression("array_to_string(\(self), \(bind: separator)\(null))", as: String?.self)
    }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
    public func stringToArray(separator: String, null: String? = nil) -> some QueryExpression<PostgreSQL.Array<String?>?> {
        let null: ISO_9075.Fragment = null.map { ", \(bind: $0)" } ?? ""
        return SQLQueryExpression(
            "string_to_array(\(self), \(bind: separator)\(null))",
            as: PostgreSQL.Array<String?>?.self
        )
    }
}

extension PostgreSQL.Array {
    public static func fill(_ value: some QueryExpression<Element>, count: Int) -> some QueryExpression<Self> {
        precondition(count >= 0, "array_fill needs a non-negative length, got \(count)")
        return SQLQueryExpression("array_fill(\(value), ARRAY[\(raw: count)])", as: Self.self)
    }
}
