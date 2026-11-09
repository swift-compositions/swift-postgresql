public import ISO_9075_Foundation
public import SQL

extension Table {
    public static func createGINIndex<Value: PostgreSQL.JSON.Document>(
        name: String? = nil,
        on column: KeyPath<TableColumns, TableColumn<Self, Value>>,
        operatorClass: PostgreSQL.JSON.OperatorClass = .jsonbOps
    ) -> SQLQueryExpression<()> {
        let columnName = columns[keyPath: column].name
        return SQLQueryExpression(
            "CREATE INDEX \(quote: name ?? "idx_\(tableName)_\(columnName)_gin") ON \(indexTarget) USING GIN (\(quote: columnName)\(operatorClass.suffix))"
        )
    }

    public static func createGINIndex<Value: PostgreSQL.JSON.Document>(
        name: String? = nil,
        on column: KeyPath<TableColumns, TableColumn<Self, Value>>,
        path: [String],
        operatorClass: PostgreSQL.JSON.OperatorClass = .jsonbOps
    ) -> SQLQueryExpression<()> {
        let columnName = columns[keyPath: column].name
        return SQLQueryExpression(
            "CREATE INDEX \(quote: name ?? "idx_\(tableName)_\(columnName)_\(path.joined(separator: "_"))_gin") ON \(indexTarget) USING GIN ((\(quote: columnName) #> \(PostgreSQL.JSON.textArrayLiteral(path)))\(operatorClass.suffix))"
        )
    }

    public static func createBTreeIndex<Value: PostgreSQL.JSON.Document>(
        name: String? = nil,
        on column: KeyPath<TableColumns, TableColumn<Self, Value>>
    ) -> SQLQueryExpression<()> {
        let columnName = columns[keyPath: column].name
        return SQLQueryExpression(
            "CREATE INDEX \(quote: name ?? "idx_\(tableName)_\(columnName)_btree") ON \(indexTarget) USING BTREE (\(quote: columnName))"
        )
    }

    private static var indexTarget: ISO_9075.Fragment {
        schemaName.map { schema -> ISO_9075.Fragment in "\(quote: schema).\(quote: tableName)" } ?? "\(quote: tableName)"
    }
}

extension PostgreSQL.JSON.OperatorClass {
    fileprivate var suffix: ISO_9075.Fragment {
        switch self {
        case .jsonbOps: ""
        case .jsonbPathOps: " \(raw: rawValue)"
        }
    }
}
