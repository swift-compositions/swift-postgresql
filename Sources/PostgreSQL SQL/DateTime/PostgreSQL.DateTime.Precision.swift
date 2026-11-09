extension PostgreSQL.DateTime {
    public enum Precision: String, Sendable, CaseIterable {
        case year
        case month
        case day
        case hour
        case minute
        case second
    }
}
