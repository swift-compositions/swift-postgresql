public import ISO_9075_Foundation

extension PostgreSQL {
    public enum Isolation: String, Hashable, Sendable, CaseIterable {
        case readUncommitted = "READ UNCOMMITTED"
        case readCommitted = "READ COMMITTED"
        case repeatableRead = "REPEATABLE READ"
        case serializable = "SERIALIZABLE"
    }
}

extension PostgreSQL.Isolation {
    public var begin: ISO.`9075`.Fragment {
        "BEGIN ISOLATION LEVEL \(raw: rawValue)"
    }
}
