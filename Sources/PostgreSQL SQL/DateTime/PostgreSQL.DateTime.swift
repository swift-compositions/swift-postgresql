public import SQL
public import Time

extension PostgreSQL {
    public enum DateTime {}
}

extension PostgreSQL.DateTime {
    public static func now() -> some QueryExpression<Time.Instant> {
        SQLQueryExpression("now()", as: Time.Instant.self)
    }
}
