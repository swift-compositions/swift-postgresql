extension PostgreSQL.Trigger {
    public enum Level: String, Sendable, Hashable, CaseIterable {
        case row = "ROW"
        case statement = "STATEMENT"
    }
}
