extension PostgreSQL.Notification {
    public struct Change<Row> {
        public let operation: Operation
        public let new: Row?
        public let old: Row?

        public init(operation: Operation, new: Row?, old: Row?) {
            self.operation = operation
            self.new = new
            self.old = old
        }
    }
}

extension PostgreSQL.Notification.Change: Encodable where Row: Encodable {}

extension PostgreSQL.Notification.Change: Decodable where Row: Decodable {}

extension PostgreSQL.Notification.Change: Equatable where Row: Equatable {}

extension PostgreSQL.Notification.Change: Hashable where Row: Hashable {}

extension PostgreSQL.Notification.Change: Sendable where Row: Sendable {}
