internal import ISO_9075_Foundation

extension PostgreSQL.Window {
    public struct Frame: Sendable, Hashable {
        public let unit: Unit
        public let start: Bound
        public let end: Bound?
        public let exclusion: Exclusion?

        public init(_ unit: Unit, from start: Bound, to end: Bound? = nil, excluding exclusion: Exclusion? = nil) {
            self.unit = unit
            self.start = start
            self.end = end
            self.exclusion = exclusion
        }

        var queryFragment: ISO_9075.Fragment {
            let extent: ISO_9075.Fragment =
                switch end {
                case let end?: "BETWEEN \(start.queryFragment) AND \(end.queryFragment)"
                case nil: start.queryFragment
                }
            let exclusion: ISO_9075.Fragment = self.exclusion.map { " \(raw: $0.rawValue)" } ?? ""
            return "\(raw: unit.rawValue) \(extent)\(exclusion)"
        }
    }
}
