extension PostgreSQL.TextSearch {
    public protocol Document {}
}

extension PostgreSQL.TextSearch.Vector: PostgreSQL.TextSearch.Document {}

extension Optional: PostgreSQL.TextSearch.Document where Wrapped: PostgreSQL.TextSearch.Document {}
