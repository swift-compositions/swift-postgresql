public import ISO_9075_Call_Level_Interface
internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Notification {
    public struct Channel<Payload>: Sendable {
        public let name: String
        let encoding: @Sendable (Payload) -> ISO_9075.Fragment
        let decoding: @Sendable (String) throws(ISO_9075.Error) -> Payload

        init(
            name: String,
            encode: @escaping @Sendable (Payload) -> ISO_9075.Fragment,
            decode: @escaping @Sendable (String) throws(ISO_9075.Error) -> Payload
        ) {
            precondition(!name.isEmpty, "a notification channel needs a name")
            precondition(name.utf8.count <= 63, "PostgreSQL truncates channel names beyond 63 bytes: \(name)")
            precondition(!name.contains("\"") && !name.contains("\u{0}"), "a channel name cannot hold a double quote or NUL: \(name)")
            self.name = name
            self.encoding = encode
            self.decoding = decode
        }
    }
}

extension PostgreSQL.Notification.Channel where Payload == String {
    public init(_ name: String) {
        self.init(name: name, encode: { "\(ISO_9075.Value.text($0))" }, decode: { $0 })
    }
}

extension PostgreSQL.Notification.Channel where Payload: Codable {
    public init(json name: String) {
        self.init(
            name: name,
            encode: { "\(PostgreSQL.JSONB(queryOutput: $0).textBinding)" },
            decode: { payload throws(ISO_9075.Error) in
                do {
                    return try PostgreSQL.JSONB<Payload>(text: payload).queryOutput
                } catch {
                    throw .decoding("\(error) in a notification on \(name)")
                }
            }
        )
    }
}

extension PostgreSQL.Notification.Channel {
    public func notify(_ payload: Payload) -> SQLQueryExpression<()> {
        SQLQueryExpression("SELECT pg_notify(\(bind: name), \(encoding(payload)))")
    }

    public func decode(_ payload: String) throws(ISO_9075.Error) -> Payload {
        try decoding(payload)
    }

    public func listen() -> SQLQueryExpression<()> {
        SQLQueryExpression("LISTEN \(quote: name)")
    }

    public func unlisten() -> SQLQueryExpression<()> {
        SQLQueryExpression("UNLISTEN \(quote: name)")
    }
}
