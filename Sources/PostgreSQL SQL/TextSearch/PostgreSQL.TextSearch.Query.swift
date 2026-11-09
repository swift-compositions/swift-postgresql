public import ISO_9075_Foundation
public import SQL

extension PostgreSQL.TextSearch {
    public struct Query: Sendable, Hashable {
        public let text: String

        public init(_ text: String) {
            self.text = text
        }
    }
}

extension PostgreSQL.TextSearch.Query: QueryRepresentable {}

extension PostgreSQL.TextSearch.Query: QueryBindable {
    public var queryBinding: ISO_9075.Value { .text(text) }

    public var queryFragment: ISO_9075.Fragment { "CAST(\(queryBinding) AS TSQUERY)" }
}

extension PostgreSQL.TextSearch.Query: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        self.init(try String(decoder: &decoder))
    }
}

extension PostgreSQL.TextSearch.Query: PostgreSQL.DataType {
    public static var typeName: String { "TSQUERY" }

    public static var valueKind: ISO_9075.Value.Kind { .text }
}
