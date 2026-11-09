extension PostgreSQL.Window.Frame {
    public enum Unit: String, Sendable, Hashable, CaseIterable {
        case rows = "ROWS"
        case range = "RANGE"
        case groups = "GROUPS"
    }
}
