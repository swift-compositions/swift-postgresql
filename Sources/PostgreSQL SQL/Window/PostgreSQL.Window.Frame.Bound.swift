internal import ISO_9075_Foundation

extension PostgreSQL.Window.Frame {
    public enum Bound: Sendable, Hashable {
        case unboundedPreceding
        case preceding(Int)
        case currentRow
        case following(Int)
        case unboundedFollowing

        var queryFragment: ISO_9075.Fragment {
            switch self {
            case .unboundedPreceding: "UNBOUNDED PRECEDING"
            case .preceding(let offset): Self.offset(offset, "PRECEDING")
            case .currentRow: "CURRENT ROW"
            case .following(let offset): Self.offset(offset, "FOLLOWING")
            case .unboundedFollowing: "UNBOUNDED FOLLOWING"
            }
        }

        private static func offset(_ offset: Int, _ direction: String) -> ISO_9075.Fragment {
            precondition(offset >= 0, "a \(direction) offset must not be negative, got \(offset)")
            return "\(raw: offset) \(raw: direction)"
        }
    }
}
