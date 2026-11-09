extension PostgreSQL.JSON {
    public enum OperatorClass: String, Sendable, Hashable, CaseIterable {
        case jsonbOps = "jsonb_ops"
        case jsonbPathOps = "jsonb_path_ops"
    }
}
