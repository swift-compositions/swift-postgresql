public import SQL

extension PostgreSQL.DateTime {
    public struct Field<Value: QueryBindable>: Sendable {
        let name: String

        private init(_ name: String) {
            self.name = name
        }
    }
}

extension PostgreSQL.DateTime.Field where Value == Int {
    public static var year: Self { Self("YEAR") }

    public static var month: Self { Self("MONTH") }

    public static var day: Self { Self("DAY") }

    public static var hour: Self { Self("HOUR") }

    public static var minute: Self { Self("MINUTE") }

    public static var dow: Self { Self("DOW") }

    public static var doy: Self { Self("DOY") }
}

extension PostgreSQL.DateTime.Field where Value == Double {
    public static var epoch: Self { Self("EPOCH") }

    public static var second: Self { Self("SECOND") }
}
