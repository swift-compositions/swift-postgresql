public import Byte

extension PostgreSQL.JSON {
    public protocol Document {}
}

extension [Byte]: PostgreSQL.JSON.Document {}

extension PostgreSQL.JSONB: PostgreSQL.JSON.Document {}

extension Optional: PostgreSQL.JSON.Document where Wrapped: PostgreSQL.JSON.Document {}
