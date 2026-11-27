#if PostgresNIO && !os(Windows)
    public import PostgreSQL_SQL
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension PostgreSQL.Connection {
        @_lifetime(borrow self)
        public func cursor<Value>(
            _ statement: ISO.`9075`.Fragment,
            batch: Int,
            decoding: @escaping (inout QueryRowDecoder<PostgreSQL.Row>) throws(QueryDecodingError) -> Value
        ) throws(ISO.`9075`.Error) -> PostgreSQL.Cursor<Value> {
            try PostgreSQL.Cursor(statement, on: self, batch: batch, decode: decoding)
        }
    }

    extension SQL.Statement {
        @_lifetime(borrow connection)
        public func fetchCursor(
            _ connection: borrowing PostgreSQL.Connection,
            batch: Int
        ) throws(ISO.`9075`.Error) -> PostgreSQL.Cursor<QueryValue.QueryOutput> where QueryValue: QueryRepresentable {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try QueryValue(decoder: &decoder).queryOutput
            }
        }

        @_lifetime(borrow connection)
        public func fetchCursor<each Value: QueryRepresentable>(
            _ connection: borrowing PostgreSQL.Connection,
            batch: Int
        ) throws(ISO.`9075`.Error) -> PostgreSQL.Cursor<(repeat (each Value).QueryOutput)>
        where QueryValue == (repeat each Value) {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((repeat each Value).self)
            }
        }
    }

    extension SelectStatement where QueryValue == (), Joins == () {
        @_lifetime(borrow connection)
        public func fetchCursor(
            _ connection: borrowing PostgreSQL.Connection,
            batch: Int
        ) throws(ISO.`9075`.Error) -> PostgreSQL.Cursor<From.QueryOutput> {
            try connection.cursor(query, batch: batch) { decoder throws(QueryDecodingError) in
                try From(decoder: &decoder).queryOutput
            }
        }
    }

    extension SQL.Table {
        @_lifetime(borrow connection)
        public static func fetchCursor(
            _ connection: borrowing PostgreSQL.Connection,
            batch: Int
        ) throws(ISO.`9075`.Error) -> PostgreSQL.Cursor<QueryOutput> {
            try all.fetchCursor(connection, batch: batch)
        }
    }
#endif
