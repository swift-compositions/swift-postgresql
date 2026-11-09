extension PostgreSQL.TextSearch {
    public enum Syntax: String, Sendable, Hashable, CaseIterable {
        case standard = "to_tsquery"
        case plain = "plainto_tsquery"
        case phrase = "phraseto_tsquery"
        case web = "websearch_to_tsquery"
    }
}
