public import Byte
public import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum JSON {}
}

extension PostgreSQL.JSON {
    public static func buildArray<each Value: QueryExpression>(
        _ values: repeat each Value,
        format: Format = .jsonb
    ) -> some QueryExpression<[Byte]> {
        SQLQueryExpression(
            "\(raw: format.rawValue)_build_array(\(fragments(repeat each values).joined(separator: ", ")))",
            as: [Byte].self
        )
    }

    public static func buildObject<each Value: QueryExpression>(
        _ pairs: repeat (String, each Value),
        format: Format = .jsonb
    ) -> some QueryExpression<[Byte]> {
        SQLQueryExpression(
            "\(raw: format.rawValue)_build_object(\(members(repeat each pairs).joined(separator: ", ")))",
            as: [Byte].self
        )
    }

    public static func object(
        keys: [String],
        values: [String],
        format: Format = .jsonb
    ) -> some QueryExpression<[Byte]> {
        precondition(keys.count == values.count, "\(format.rawValue)_object needs exactly one value per key")
        return SQLQueryExpression(
            "\(raw: format.rawValue)_object(\(textArray(keys)), \(textArray(values)))",
            as: [Byte].self
        )
    }

    public static func row<T: Table>(_ table: T.Type) -> some QueryExpression<[Byte]> {
        SQLQueryExpression("row_to_json(\(table).*)", as: [Byte].self)
    }
}

extension PostgreSQL.JSON {
    static func textArray(_ elements: [String]) -> ISO_9075.Fragment {
        "\(PostgreSQL.Array<String>(elements))::text[]"
    }

    static func textArrayLiteral(_ elements: [String]) -> ISO_9075.Fragment {
        "\(text: "{" + elements.map(quotedArrayElement).joined(separator: ",") + "}")::text[]"
    }

    private static func quotedArrayElement(_ element: String) -> String {
        "\"" + element.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"") + "\""
    }

    static func document(_ value: some Codable) -> ISO_9075.Fragment {
        "\(PostgreSQL.JSONB(queryOutput: value))::jsonb"
    }

    static func fragments<each Value: QueryExpression>(
        _ values: repeat each Value
    ) -> [ISO_9075.Fragment] {
        var fragments: [ISO_9075.Fragment] = []
        for value in repeat each values {
            fragments.append(value.queryFragment)
        }
        return fragments
    }

    static func members<each Value: QueryExpression>(
        _ pairs: repeat (String, each Value)
    ) -> [ISO_9075.Fragment] {
        var members: [ISO_9075.Fragment] = []
        for pair in repeat each pairs {
            members.append("\(bind: pair.0), \(pair.1)")
        }
        return members
    }
}
