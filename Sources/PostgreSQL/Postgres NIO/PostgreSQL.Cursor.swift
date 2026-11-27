#if PostgresNIO && !os(Windows)
    public import PostgreSQL_SQL
    public import ISO_9075_Call_Level_Interface
    public import SQL
    internal import Synchronization

    extension PostgreSQL {
        /// The rows of one statement, fetched from the server a batch at a time. It reads through the connection it
        /// was made on, so it cannot outlive the scope that lent that connection.
        public struct Cursor<Element>: ~Copyable, ~Escapable {
            let core: PostgreSQL.Connection.Core
            let name: ISO.`9075`.Identifier
            let batch: Int
            let decode: (inout QueryRowDecoder<PostgreSQL.Row>) throws(QueryDecodingError) -> Element
            var buffer: [PostgreSQL.Row] = []
            var isOpen: Bool
            var isExhausted = false

            @_lifetime(borrow connection)
            init(
                _ statement: ISO.`9075`.Fragment,
                on connection: borrowing PostgreSQL.Connection,
                batch: Int,
                decode: @escaping (inout QueryRowDecoder<PostgreSQL.Row>) throws(QueryDecodingError) -> Element
            ) throws(ISO.`9075`.Error) {
                precondition(batch > 0, "A cursor fetches at least one row per batch")
                self.core = connection.core
                self.name = ISO.`9075`.Identifier("cursor_\(PostgreSQL.Connection.names.add(1, ordering: .relaxed).newValue)")
                self.batch = batch
                self.decode = decode
                self.isOpen = !statement.isEmpty
                if isOpen {
                    _ = try PostgreSQL.Connection(core).execute("DECLARE \(name) NO SCROLL CURSOR FOR \(statement)")
                }
            }

            public mutating func next() throws(ISO.`9075`.Error) -> Element? {
                if buffer.isEmpty, isOpen, !isExhausted {
                    buffer = try PostgreSQL.Connection(core).fetchAll("FETCH FORWARD \(raw: String(batch)) FROM \(name)") { $0 }
                    isExhausted = buffer.count < batch
                }
                guard !buffer.isEmpty else { return nil }
                var decoder = QueryRowDecoder(row: buffer.removeFirst())
                do {
                    return try decode(&decoder)
                } catch {
                    throw .decoding("\(error) in cursor \(name.name)")
                }
            }

            public mutating func close() throws(ISO.`9075`.Error) {
                guard isOpen else { return }
                _ = try PostgreSQL.Connection(core).execute("CLOSE \(name)")
                buffer = []
                isOpen = false
            }

            public mutating func fetchAll() throws(ISO.`9075`.Error) -> [Element] {
                var elements: [Element] = []
                while let element = try next() {
                    elements.append(element)
                }
                return elements
            }
        }
    }
#endif
