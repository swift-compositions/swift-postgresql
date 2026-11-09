public import PostgreSQL_SQL
#if PostgresNIO
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension PostgreSQL.Connection {
        public func fetchAll<Value>(
            _ statement: ISO_9075.Fragment,
            decoding: (inout PostgreSQL.Decoder) throws(QueryDecodingError) -> Value
        ) throws(ISO_9075.Error) -> [Value] {
            try fetchAll(statement) { row throws(ISO_9075.Error) in
                var decoder = PostgreSQL.Decoder(row: row)
                do {
                    return try decoding(&decoder)
                } catch {
                    throw .decoding("\(error)")
                }
            }
        }

        public func cursor<Value>(
            _ statement: ISO_9075.Fragment,
            batch: Int,
            decoding: @escaping (inout PostgreSQL.Decoder) throws(QueryDecodingError) -> Value
        ) throws(ISO_9075.Error) -> PostgreSQL.Cursor<Value> {
            try PostgreSQL.Cursor(statement, on: self, batch: batch, decode: decoding)
        }
    }

    extension SQL.Statement {
        public func execute(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) where QueryValue == () {
            _ = try connection.execute(query)
        }

        public func fetchAll(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> [QueryValue.QueryOutput] where QueryValue: QueryRepresentable {
            try connection.fetchAll(query) { decoder throws(QueryDecodingError) in try QueryValue(decoder: &decoder).queryOutput }
        }

        public func fetchOne(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> QueryValue.QueryOutput? where QueryValue: QueryRepresentable {
            try fetchAll(connection).first
        }

        public func fetchCursor(
            _ connection: PostgreSQL.Connection,
            batch: Int
        ) throws(ISO_9075.Error) -> PostgreSQL.Cursor<QueryValue.QueryOutput> where QueryValue: QueryRepresentable {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try QueryValue(decoder: &decoder).queryOutput
            }
        }

        public func fetchAll<each Value: QueryRepresentable>(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> [(repeat (each Value).QueryOutput)] where QueryValue == (repeat each Value) {
            try connection.fetchAll(query) { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((repeat each Value).self)
            }
        }

        public func fetchOne<each Value: QueryRepresentable>(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> (repeat (each Value).QueryOutput)? where QueryValue == (repeat each Value) {
            try fetchAll(connection).first
        }

        public func fetchCursor<each Value: QueryRepresentable>(
            _ connection: PostgreSQL.Connection,
            batch: Int
        ) throws(ISO_9075.Error) -> PostgreSQL.Cursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((repeat each Value).self)
            }
        }
    }

    extension SelectStatement where QueryValue == (), Joins == () {
        public func fetchCount(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> Int {
            try asSelect().count().fetchOne(connection) ?? 0
        }

        public func fetchAll(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> [From.QueryOutput] {
            try connection.fetchAll(query) { decoder throws(QueryDecodingError) in try From(decoder: &decoder).queryOutput }
        }

        public func fetchOne(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> From.QueryOutput? {
            try connection.fetchAll(asSelect().limit(1).query) { decoder throws(QueryDecodingError) in
                try From(decoder: &decoder).queryOutput
            }
            .first
        }

        public func fetchCursor(
            _ connection: PostgreSQL.Connection,
            batch: Int
        ) throws(ISO_9075.Error) -> PostgreSQL.Cursor<From.QueryOutput> {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try From(decoder: &decoder).queryOutput
            }
        }
    }

    extension SelectStatement where QueryValue == () {
        public func fetchAll<each Join: SQL.Table>(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> [(From.QueryOutput, repeat (each Join).QueryOutput)] where Joins == (repeat each Join) {
            try connection.fetchAll(query) { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((From, repeat each Join).self)
            }
        }

        public func fetchOne<each Join: SQL.Table>(
            _ connection: PostgreSQL.Connection
        ) throws(ISO_9075.Error) -> (From.QueryOutput, repeat (each Join).QueryOutput)? where Joins == (repeat each Join) {
            try connection.fetchAll(asSelect().limit(1).query) { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((From, repeat each Join).self)
            }
            .first
        }
    }

    extension SQL.Table {
        public static func fetchAll(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> [QueryOutput] {
            try all.fetchAll(connection)
        }

        public static func fetchOne(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> QueryOutput? {
            try all.fetchOne(connection)
        }

        public static func fetchCount(_ connection: PostgreSQL.Connection) throws(ISO_9075.Error) -> Int {
            try all.fetchCount(connection)
        }

        public static func fetchCursor(
            _ connection: PostgreSQL.Connection,
            batch: Int
        ) throws(ISO_9075.Error) -> PostgreSQL.Cursor<QueryOutput> {
            try all.fetchCursor(connection, batch: batch)
        }
    }
#endif
