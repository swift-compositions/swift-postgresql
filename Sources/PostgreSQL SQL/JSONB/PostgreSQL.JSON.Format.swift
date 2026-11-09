extension PostgreSQL.JSON {
    public enum Format: String, Sendable, Hashable, CaseIterable {
        case json
        case jsonb
    }
}
