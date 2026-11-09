extension PostgreSQL.Notification {
    public enum Operation: String, Codable, Sendable, Hashable, CaseIterable {
        case insert = "INSERT"
        case update = "UPDATE"
        case delete = "DELETE"
    }
}
