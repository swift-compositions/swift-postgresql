internal import ISO_9075_Foundation
public import SQL

extension Table {
    public static func addSearchVector(
        _ name: String,
        configuration: PostgreSQL.TextSearch.Configuration,
        sources: [PostgreSQL.TextSearch.Source<Self>],
        ifNotExists: Bool = false
    ) -> SQLQueryExpression<()> {
        precondition(!sources.isEmpty, "a search vector needs at least one source column")
        let vector = sources.map { source -> ISO_9075.Fragment in
            "setweight(to_tsvector(\(configuration.queryFragment), coalesce(\(quote: source.column), '')), \(text: source.weight.rawValue))"
        }
        return SQLQueryExpression(
            "ALTER TABLE \(Self.self) ADD COLUMN \(raw: ifNotExists ? "IF NOT EXISTS " : "")\(quote: name) TSVECTOR GENERATED ALWAYS AS (\(vector.joined(separator: " || "))) STORED"
        )
    }

    public static func createGINIndex<Value: PostgreSQL.TextSearch.Document>(
        name: String? = nil,
        on column: KeyPath<TableColumns, TableColumn<Self, Value>>
    ) -> SQLQueryExpression<()> {
        searchIndex(name: name, on: columns[keyPath: column].name, method: "GIN")
    }

    public static func createGiSTIndex<Value: PostgreSQL.TextSearch.Document>(
        name: String? = nil,
        on column: KeyPath<TableColumns, TableColumn<Self, Value>>
    ) -> SQLQueryExpression<()> {
        searchIndex(name: name, on: columns[keyPath: column].name, method: "GIST")
    }

    private static func searchIndex(name: String?, on column: String, method: String) -> SQLQueryExpression<()> {
        SQLQueryExpression(
            "CREATE INDEX \(quote: name ?? "idx_\(tableName)_\(column)_\(method.lowercased())") ON \(Self.self) USING \(raw: method) (\(quote: column))"
        )
    }
}
