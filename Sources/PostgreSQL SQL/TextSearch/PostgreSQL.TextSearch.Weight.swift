extension PostgreSQL.TextSearch {
    public enum Weight: String, Sendable, Hashable, CaseIterable {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
    }
}
