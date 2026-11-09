public import SQL

extension PostgreSQL {
    public enum Collation: String, SQL.Collation, Sendable, CaseIterable {
        case c = "C"
        case posix = "POSIX"
        case enUS = "en_US"
        case enUSUTF8 = "en_US.utf8"
        case `default` = "default"
        case unicode = "unicode"
        case ucsBasic = "ucs_basic"

        public var name: String { rawValue }
    }
}
