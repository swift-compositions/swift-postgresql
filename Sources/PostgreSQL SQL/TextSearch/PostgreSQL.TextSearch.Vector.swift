public import ISO_9075_Foundation
public import SQL

extension PostgreSQL.TextSearch {
    public struct Vector: Sendable, Hashable {
        public let text: String

        public init(_ text: String) {
            self.text = text
        }
    }
}

extension PostgreSQL.TextSearch.Vector: QueryRepresentable {}

extension PostgreSQL.TextSearch.Vector: QueryBindable {
    public var queryBinding: ISO_9075.Value { .text(text) }

    public var queryFragment: ISO_9075.Fragment { "CAST(\(queryBinding) AS TSVECTOR)" }
}

extension PostgreSQL.TextSearch.Vector: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(try String(decoder: &decoder))
    }
}

extension PostgreSQL.TextSearch.Vector: PostgreSQL.DataType {
    public static var typeName: String { "TSVECTOR" }

    public static var valueKind: ISO_9075.Value.Kind { .text }
}
