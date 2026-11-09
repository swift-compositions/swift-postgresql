extension PostgreSQL.Window.Frame {
    public enum Exclusion: String, Sendable, Hashable, CaseIterable {
        case currentRow = "EXCLUDE CURRENT ROW"
        case group = "EXCLUDE GROUP"
        case ties = "EXCLUDE TIES"
        case noOthers = "EXCLUDE NO OTHERS"
    }
}
