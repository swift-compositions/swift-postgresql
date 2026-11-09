public import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Window {
    public struct Function<QueryValue>: QueryExpression, Sendable {
        let call: ISO_9075.Fragment
        let window: ISO_9075.Fragment

        init(_ name: String, _ arguments: [ISO_9075.Fragment] = []) {
            self.init(call: "\(raw: name)(\(arguments.joined(separator: ", ")))", window: "()")
        }

        init(call: ISO_9075.Fragment, window: ISO_9075.Fragment) {
            self.call = call
            self.window = window
        }

        public init(aggregate: some QueryExpression<QueryValue>) {
            self.init(call: aggregate.queryFragment, window: "()")
        }

        public func over() -> Self {
            Self(call: call, window: "()")
        }

        public func over(_ specify: (Specification) -> Specification) -> Self {
            Self(call: call, window: "(\(specify(Specification()).queryFragment))")
        }

        public func over(_ name: String) -> Self {
            Self(call: call, window: "\(quote: name)")
        }

        public var queryFragment: ISO_9075.Fragment {
            "\(call) OVER \(window)"
        }
    }
}

extension Select {
    public func window(
        _ name: String,
        _ specify: (PostgreSQL.Window.Specification) -> PostgreSQL.Window.Specification
    ) -> Self {
        window(name, as: specify(PostgreSQL.Window.Specification()).queryFragment)
    }
}
