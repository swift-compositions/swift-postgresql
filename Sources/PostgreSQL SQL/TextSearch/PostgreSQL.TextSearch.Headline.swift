extension PostgreSQL.TextSearch {
    public struct Headline: Sendable, Hashable {
        public var startSelection: String?
        public var stopSelection: String?
        public var maxWords: Int?
        public var minWords: Int?
        public var shortWord: Int?
        public var highlightAll: Bool?
        public var maxFragments: Int?
        public var fragmentDelimiter: String?

        public init(
            startSelection: String? = nil,
            stopSelection: String? = nil,
            maxWords: Int? = nil,
            minWords: Int? = nil,
            shortWord: Int? = nil,
            highlightAll: Bool? = nil,
            maxFragments: Int? = nil,
            fragmentDelimiter: String? = nil
        ) {
            self.startSelection = startSelection
            self.stopSelection = stopSelection
            self.maxWords = maxWords
            self.minWords = minWords
            self.shortWord = shortWord
            self.highlightAll = highlightAll
            self.maxFragments = maxFragments
            self.fragmentDelimiter = fragmentDelimiter
        }

        var text: String? {
            let options = [
                startSelection.map { "StartSel=\(Self.quoted($0))" },
                stopSelection.map { "StopSel=\(Self.quoted($0))" },
                maxWords.map { "MaxWords=\($0)" },
                minWords.map { "MinWords=\($0)" },
                shortWord.map { "ShortWord=\($0)" },
                highlightAll.map { "HighlightAll=\($0)" },
                maxFragments.map { "MaxFragments=\($0)" },
                fragmentDelimiter.map { "FragmentDelimiter=\(Self.quoted($0))" },
            ]
            .compactMap(\.self)
            return options.isEmpty ? nil : options.joined(separator: ", ")
        }

        private static func quoted(_ value: String) -> String {
            "\"" + value.replacing("\"", with: "\"\"") + "\""
        }
    }
}
