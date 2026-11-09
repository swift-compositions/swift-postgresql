internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public struct Trigger<On: Table>: Sendable, Hashable {
        public let name: String
        public let timing: Timing
        public let events: [Event]
        public let level: Level
        public let function: PostgreSQL.Function

        public init(
            _ name: String,
            _ timing: Timing,
            _ events: [Event],
            level: Level = .row,
            executing function: PostgreSQL.Function
        ) {
            precondition(!name.isEmpty, "a trigger needs a name")
            precondition(!events.isEmpty, "a trigger fires on at least one event")
            self.name = name
            self.timing = timing
            self.events = events
            self.level = level
            self.function = function
        }

        public func create(orReplace: Bool = false) -> SQLQueryExpression<()> {
            SQLQueryExpression(
                "CREATE \(raw: orReplace ? "OR REPLACE " : "")TRIGGER \(quote: name) \(raw: timing.rawValue) \(events.map(\.queryFragment).joined(separator: " OR ")) ON \(On.self) FOR EACH \(raw: level.rawValue) EXECUTE FUNCTION \(function.reference)()"
            )
        }

        public func drop(ifExists: Bool = false, cascade: Bool = false) -> SQLQueryExpression<()> {
            SQLQueryExpression(
                "DROP TRIGGER \(raw: ifExists ? "IF EXISTS " : "")\(quote: name) ON \(On.self)\(raw: cascade ? " CASCADE" : "")"
            )
        }
    }
}
