extension PostgreSQL.Binary {
    public enum Encoding: String, Sendable, CaseIterable {
        case base64
        case escape
        case hex
    }
}
