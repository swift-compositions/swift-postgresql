public import SQL

extension PostgreSQL.TextSearch {
    public struct Source<On: Table>: Sendable, Hashable {
        public let column: String
        public let weight: Weight

        public init<Value>(_ column: KeyPath<On.TableColumns, TableColumn<On, Value>>, weight: Weight)
        where Value: QueryRepresentable & QueryBindable & _OptionalPromotable<String?> {
            self.column = On.columns[keyPath: column].name
            self.weight = weight
        }
    }
}
