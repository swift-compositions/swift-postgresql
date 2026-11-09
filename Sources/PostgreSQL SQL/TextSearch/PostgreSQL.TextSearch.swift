internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum TextSearch {}
}

extension PostgreSQL.TextSearch {
    public static func vector(
        _ text: some QueryExpression<some _OptionalPromotable<String?>>,
        configuration: Configuration
    ) -> some QueryExpression<Vector> {
        SQLQueryExpression("to_tsvector(\(configuration.queryFragment), \(text))", as: Vector.self)
    }

    public static func query(
        _ text: some QueryExpression<some _OptionalPromotable<String?>>,
        configuration: Configuration,
        syntax: Syntax = .web
    ) -> some QueryExpression<Query> {
        SQLQueryExpression("\(raw: syntax.rawValue)(\(configuration.queryFragment), \(text))", as: Query.self)
    }
}
