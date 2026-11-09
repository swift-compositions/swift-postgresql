internal import ISO_9075_Foundation
public import SQL
public import Time

extension QueryExpression where QueryValue == Time.Instant {
    public func extract<Value>(_ field: PostgreSQL.DateTime.Field<Value>) -> some QueryExpression<Value> {
        SQLQueryExpression("EXTRACT(\(raw: field.name) FROM \(self))", as: Value.self)
    }

    public func dateTrunc(_ precision: PostgreSQL.DateTime.Precision) -> some QueryExpression<Time.Instant> {
        SQLQueryExpression("DATE_TRUNC(\(text: precision.rawValue), \(self))", as: Time.Instant.self)
    }
}
