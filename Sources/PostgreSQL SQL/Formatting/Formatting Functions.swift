internal import ISO_9075_Foundation
public import SQL
public import Time

extension QueryExpression where QueryValue == Time.Instant {
    public func toChar(_ format: String) -> some QueryExpression<String> {
        SQLQueryExpression("to_char(\(self), \(bind: format))", as: String.self)
    }

    public func age() -> some QueryExpression<String> {
        SQLQueryExpression("age(\(self))", as: String.self)
    }

    public func age(from other: some QueryExpression<Time.Instant>) -> some QueryExpression<String> {
        SQLQueryExpression("age(\(self), \(other))", as: String.self)
    }
}

extension QueryExpression where QueryValue: Numeric & QueryBindable {
    public func toChar(_ format: String) -> some QueryExpression<String> {
        SQLQueryExpression("to_char(\(self), \(bind: format))", as: String.self)
    }
}

extension QueryExpression where QueryValue == Double {
    public func toTimestamp() -> some QueryExpression<Time.Instant> {
        SQLQueryExpression("to_timestamp(\(self))", as: Time.Instant.self)
    }
}

extension QueryExpression where QueryValue == String {
    public func toDate(format: String) -> some QueryExpression<Time.Instant> {
        SQLQueryExpression("to_date(\(self), \(bind: format))", as: Time.Instant.self)
    }

    public func toTimestamp(format: String) -> some QueryExpression<Time.Instant> {
        SQLQueryExpression("to_timestamp(\(self), \(bind: format))", as: Time.Instant.self)
    }

    public func toNumber(format: String) -> some QueryExpression<Double> {
        SQLQueryExpression("to_number(\(self), \(bind: format))", as: Double.self)
    }

    public func justifyDays() -> some QueryExpression<String> {
        SQLQueryExpression("justify_days(\(self))", as: String.self)
    }

    public func justifyHours() -> some QueryExpression<String> {
        SQLQueryExpression("justify_hours(\(self))", as: String.self)
    }

    public func justifyInterval() -> some QueryExpression<String> {
        SQLQueryExpression("justify_interval(\(self))", as: String.self)
    }
}
