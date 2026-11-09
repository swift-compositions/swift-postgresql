internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum Notification {}
}

extension PostgreSQL.Notification {
    public static func unlistenAll() -> SQLQueryExpression<()> {
        SQLQueryExpression("UNLISTEN *")
    }
}
