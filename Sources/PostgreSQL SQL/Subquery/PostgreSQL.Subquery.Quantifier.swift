extension PostgreSQL.Subquery {
    public enum Quantifier: String, Sendable, Hashable, CaseIterable {
        case `any` = "ANY"
        case all = "ALL"
        case `some` = "SOME"
    }
}
