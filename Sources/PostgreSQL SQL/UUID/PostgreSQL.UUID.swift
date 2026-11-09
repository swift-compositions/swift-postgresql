internal import ISO_9075_Foundation
public import RFC_4122
public import SQL

extension PostgreSQL {
    public enum UUID {}
}

extension PostgreSQL.UUID {
    public static func random() -> some QueryExpression<RFC_4122.UUID> {
        SQLQueryExpression("gen_random_uuid()", as: RFC_4122.UUID.self)
    }

    public static func v4() -> some QueryExpression<RFC_4122.UUID> {
        SQLQueryExpression("uuidv4()", as: RFC_4122.UUID.self)
    }

    public static func v7() -> some QueryExpression<RFC_4122.UUID> {
        SQLQueryExpression("uuidv7()", as: RFC_4122.UUID.self)
    }

    public static func v7(shift: String) -> some QueryExpression<RFC_4122.UUID> {
        SQLQueryExpression("uuidv7(\(text: shift)::interval)", as: RFC_4122.UUID.self)
    }
}
