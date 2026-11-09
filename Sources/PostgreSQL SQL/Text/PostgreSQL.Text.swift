internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum Text {}
}

extension PostgreSQL.Text {
    public static func chr(_ code: Int) -> some QueryExpression<String> {
        SQLQueryExpression("chr(\(raw: code))", as: String.self)
    }

    public static func concatenate<each Value: QueryExpression>(
        separator: some QueryExpression<String>,
        _ values: repeat each Value
    ) -> some QueryExpression<String> {
        var arguments: [ISO_9075.Fragment] = [separator.queryFragment]
        for value in repeat each values {
            arguments.append(value.queryFragment)
        }
        precondition(arguments.count > 1, "concat_ws needs at least one value after the separator")
        return SQLQueryExpression("concat_ws(\(arguments.joined(separator: ", ")))", as: String.self)
    }

    public static func format<each Argument: QueryExpression>(
        _ template: some QueryExpression<String>,
        _ arguments: repeat each Argument
    ) -> some QueryExpression<String> {
        var fragments: [ISO_9075.Fragment] = [template.queryFragment]
        for argument in repeat each arguments {
            fragments.append(argument.queryFragment)
        }
        return SQLQueryExpression("format(\(fragments.joined(separator: ", ")))", as: String.self)
    }
}
