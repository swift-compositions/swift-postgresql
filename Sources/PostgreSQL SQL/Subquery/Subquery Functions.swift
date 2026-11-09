internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: QueryRepresentable {
    public func eq(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared("=", other)
    }

    public func neq(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared("<>", other)
    }

    public func lt(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared("<", other)
    }

    public func gt(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared(">", other)
    }

    public func lte(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared("<=", other)
    }

    public func gte(_ other: PostgreSQL.Subquery.Quantified<QueryValue>) -> some QueryExpression<Bool> {
        compared(">=", other)
    }

    private func compared(
        _ comparison: String,
        _ other: PostgreSQL.Subquery.Quantified<QueryValue>
    ) -> SQLQueryExpression<Bool> {
        SQLQueryExpression("(\(self)) \(raw: comparison) \(other.queryFragment)", as: Bool.self)
    }
}
