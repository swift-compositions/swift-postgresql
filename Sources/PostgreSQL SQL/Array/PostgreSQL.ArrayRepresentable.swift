public import SQL

extension PostgreSQL {
    public protocol ArrayRepresentable: QueryBindable {
        associatedtype Element: QueryBindable & QueryDecodable
    }
}

extension PostgreSQL.Array: PostgreSQL.ArrayRepresentable where Element: PostgreSQL.DataType {}

extension Optional: PostgreSQL.ArrayRepresentable where Wrapped: PostgreSQL.ArrayRepresentable {
    public typealias Element = Wrapped.Element
}
