internal import Foundation
internal import ISO_9075_Call_Level_Interface
internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Notification.Channel {
    public init<On: Table>(changes name: String) where Payload == PostgreSQL.Notification.Change<On>, On.QueryOutput == On {
        self.init(
            name: name,
            encode: { change in
                "json_build_object('operation', \(bind: change.operation.rawValue), 'new', \(PostgreSQL.Notification.Change<On>.json(change.new)), 'old', \(PostgreSQL.Notification.Change<On>.json(change.old)))::text"
            },
            decode: { payload throws(ISO_9075.Error) in
                do throws(QueryDecodingError) {
                    return try PostgreSQL.Notification.Change<On>(json: payload)
                } catch {
                    throw .decoding("\(error) in a notification on \(name)")
                }
            }
        )
    }
}

extension PostgreSQL.Notification.Change where Row: Table, Row.QueryOutput == Row {
    init(json text: String) throws(QueryDecodingError) {
        let object = try PostgreSQL.JSON.object(text)
        guard let operation = (object["operation"] as? String).flatMap(PostgreSQL.Notification.Operation.init(rawValue:)) else {
            throw .dataCorrupted("\(text) names no operation")
        }
        func row(_ key: String) throws(QueryDecodingError) -> Row? {
            guard let fields = object[key] as? [String: Any] else { return nil }
            var decoder = PostgreSQL.JSON.Row(fields, as: Row.self)
            return try Row(decoder: &decoder)
        }
        self.init(operation: operation, new: try row("new"), old: try row("old"))
    }

    static func json(_ row: Row?) -> ISO_9075.Fragment {
        row.map { "(SELECT row_to_json(\(quote: "row")) FROM (\($0.query)) AS \(quote: "row"))" } ?? "NULL"
    }
}
