public import PostgreSQL_SQL
#if PostgresNIO
    public import ISO_9075_Call_Level_Interface
    public import SQL
    internal import Synchronization

    extension PostgreSQL {
        public struct Cursor<Element> {
            let connection: PostgreSQL.Connection
            let name: ISO_9075.Identifier
            let batch: Int
            let decode: (inout PostgreSQL.Decoder) throws(QueryDecodingError) -> Element
            var buffer: [PostgreSQL.Row] = []
            var isOpen: Bool
            var isExhausted = false

            init(
                _ statement: ISO_9075.Fragment,
                on connection: PostgreSQL.Connection,
                batch: Int,
                decode: @escaping (inout PostgreSQL.Decoder) throws(QueryDecodingError) -> Element
            ) throws(ISO_9075.Error) {
                precondition(batch > 0, "A cursor fetches at least one row per batch")
                self.connection = connection
                self.name = ISO_9075.Identifier("cursor_\(PostgreSQL.Connection.names.add(1, ordering: .relaxed).newValue)")
                self.batch = batch
                self.decode = decode
                self.isOpen = !statement.isEmpty
                if isOpen {
                    _ = try connection.execute("DECLARE \(name) NO SCROLL CURSOR FOR \(statement)")
                }
            }

            public mutating func next() throws(ISO_9075.Error) -> Element? {
                if buffer.isEmpty, isOpen, !isExhausted {
                    buffer = try connection.fetchAll("FETCH FORWARD \(raw: String(batch)) FROM \(name)") { $0 }
                    isExhausted = buffer.count < batch
                }
                guard !buffer.isEmpty else { return nil }
                var decoder = PostgreSQL.Decoder(row: buffer.removeFirst())
                do {
                    return try decode(&decoder)
                } catch {
                    throw .decoding("\(error) in cursor \(name.name)")
                }
            }

            public mutating func close() throws(ISO_9075.Error) {
                guard isOpen else { return }
                _ = try connection.execute("CLOSE \(name)")
                buffer = []
                isOpen = false
            }

            public mutating func fetchAll() throws(ISO_9075.Error) -> [Element] {
                var elements: [Element] = []
                while let element = try next() {
                    elements.append(element)
                }
                return elements
            }
        }
    }
#endif
