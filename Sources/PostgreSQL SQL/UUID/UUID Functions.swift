internal import ISO_9075_Foundation
public import RFC_4122
public import SQL
public import Time

extension QueryExpression where QueryValue: _OptionalPromotable<RFC_4122.UUID?> {
    public func extractVersion() -> some QueryExpression<Int?> {
        SQLQueryExpression("uuid_extract_version(\(self))", as: Int?.self)
    }

    public func extractTimestamp() -> some QueryExpression<Time.Instant?> {
        SQLQueryExpression("uuid_extract_timestamp(\(self))", as: Time.Instant?.self)
    }
}
