extension PostgreSQL.Trigger {
    public enum Timing: String, Sendable, Hashable, CaseIterable {
        case before = "BEFORE"
        case after = "AFTER"
        case insteadOf = "INSTEAD OF"
    }
}
