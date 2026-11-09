internal import ISO_9075_Foundation

extension PostgreSQL.TextSearch {
    public struct Configuration: Sendable, Hashable {
        public let name: String

        public init(_ name: String) {
            precondition(!name.isEmpty, "a text search configuration needs a name")
            self.name = name
        }

        var queryFragment: ISO_9075.Fragment {
            "\(text: name)::regconfig"
        }
    }
}

extension PostgreSQL.TextSearch.Configuration {
    public static var simple: Self { Self("simple") }

    public static var english: Self { Self("english") }

    public static var dutch: Self { Self("dutch") }

    public static var german: Self { Self("german") }

    public static var french: Self { Self("french") }

    public static var spanish: Self { Self("spanish") }
}
