public import Byte
public import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: PostgreSQL.JSON.Document {
    public func setting(
        _ path: [String],
        to value: some Codable,
        createIfMissing: Bool = true
    ) -> some QueryExpression<QueryValue> {
        SQLQueryExpression(
            "jsonb_set(\(self), \(PostgreSQL.JSON.textArray(path)), \(PostgreSQL.JSON.document(value)), \(bind: createIfMissing))",
            as: QueryValue.self
        )
    }

    public func inserting(
        _ value: some Codable,
        at path: [String],
        after: Bool = false
    ) -> some QueryExpression<QueryValue> {
        SQLQueryExpression(
            "jsonb_insert(\(self), \(PostgreSQL.JSON.textArray(path)), \(PostgreSQL.JSON.document(value)), \(bind: after))",
            as: QueryValue.self
        )
    }

    public func strippingNulls() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("jsonb_strip_nulls(\(self))", as: QueryValue.self)
    }

    public func prettyFormatted() -> some QueryExpression<String> {
        SQLQueryExpression("jsonb_pretty(\(self))", as: String.self)
    }

    public func typeString() -> some QueryExpression<String> {
        SQLQueryExpression("jsonb_typeof(\(self))", as: String.self)
    }

    public func arrayLength() -> some QueryExpression<Int> {
        SQLQueryExpression("jsonb_array_length(\(self))", as: Int.self)
    }

    public func extractPath(
        _ path: [String],
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<[Byte]?> {
        SQLQueryExpression(
            "\(raw: format.rawValue)_extract_path(\(self), VARIADIC \(PostgreSQL.JSON.textArray(path)))",
            as: [Byte]?.self
        )
    }

    public func extractPathText(
        _ path: [String],
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<String?> {
        SQLQueryExpression(
            "\(raw: format.rawValue)_extract_path_text(\(self), VARIADIC \(PostgreSQL.JSON.textArray(path)))",
            as: String?.self
        )
    }

    public func pathExists(_ path: String) -> some QueryExpression<Bool> {
        SQLQueryExpression("jsonb_path_exists(\(self), \(bind: path)::jsonpath)", as: Bool.self)
    }

    public func pathQuery(_ path: String) -> some QueryExpression<[Byte]> {
        SQLQueryExpression("jsonb_path_query(\(self), \(bind: path)::jsonpath)", as: [Byte].self)
    }

    public func arrayElements(
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<[Byte]> {
        SQLQueryExpression("\(raw: format.rawValue)_array_elements(\(self))", as: [Byte].self)
    }

    public func arrayElementsText(
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<String> {
        SQLQueryExpression("\(raw: format.rawValue)_array_elements_text(\(self))", as: String.self)
    }

    public func each(
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<(String, [Byte])> {
        SQLQueryExpression("\(raw: format.rawValue)_each(\(self))", as: (String, [Byte]).self)
    }

    public func eachText(
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<(String, String)> {
        SQLQueryExpression("\(raw: format.rawValue)_each_text(\(self))", as: (String, String).self)
    }

    public func objectKeys(
        format: PostgreSQL.JSON.Format = .jsonb
    ) -> some QueryExpression<String> {
        SQLQueryExpression("\(raw: format.rawValue)_object_keys(\(self))", as: String.self)
    }
}

extension QueryExpression {
    public func toJson() -> some QueryExpression<[Byte]> {
        SQLQueryExpression("to_json(\(self))", as: [Byte].self)
    }

    public func toJsonb() -> some QueryExpression<[Byte]> {
        SQLQueryExpression("to_jsonb(\(self))", as: [Byte].self)
    }

    public func arrayToJson<Element: QueryBindable & QueryDecodable>() -> some QueryExpression<[Byte]>
    where QueryValue == PostgreSQL.Array<Element> {
        SQLQueryExpression("array_to_json(\(self))", as: [Byte].self)
    }
}
