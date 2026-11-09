extension PostgreSQL.TextSearch {
    public struct Normalization: OptionSet, Sendable, Hashable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let logLength = Self(rawValue: 1)
        public static let length = Self(rawValue: 2)
        public static let harmonicDistance = Self(rawValue: 4)
        public static let uniqueWords = Self(rawValue: 8)
        public static let logUniqueWords = Self(rawValue: 16)
        public static let unitRange = Self(rawValue: 32)
    }
}
