internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Trigger {
    public struct Event: Sendable, Hashable {
        let keyword: String
        let columns: [String]

        private init(_ keyword: String, columns: [String] = []) {
            self.keyword = keyword
            self.columns = columns
        }

        var queryFragment: ISO_9075.Fragment {
            columns.isEmpty
                ? "\(raw: keyword)"
                : "\(raw: keyword) OF \(columns.map { column -> ISO_9075.Fragment in "\(quote: column)" }.joined(separator: ", "))"
        }
    }
}

extension PostgreSQL.Trigger.Event {
    public static var insert: Self { Self("INSERT") }

    public static var update: Self { Self("UPDATE") }

    public static var delete: Self { Self("DELETE") }

    public static var truncate: Self { Self("TRUNCATE") }

    public static func update<each Value: QueryRepresentable & QueryBindable>(
        of columns: repeat KeyPath<On.TableColumns, TableColumn<On, each Value>>
    ) -> Self {
        var names: [String] = []
        for column in repeat each columns {
            names.append(On.columns[keyPath: column].name)
        }
        precondition(!names.isEmpty, "UPDATE OF names at least one column")
        return Self("UPDATE", columns: names)
    }
}
