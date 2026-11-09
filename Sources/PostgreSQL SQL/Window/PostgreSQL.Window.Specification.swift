public import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Window {
    public struct Specification: Sendable {
        let partitions: [ISO_9075.Fragment]
        let orderings: [ISO_9075.Fragment]
        let frame: Frame?

        public init() {
            self.init(partitions: [], orderings: [], frame: nil)
        }

        init(partitions: [ISO_9075.Fragment], orderings: [ISO_9075.Fragment], frame: Frame?) {
            self.partitions = partitions
            self.orderings = orderings
            self.frame = frame
        }

        var queryFragment: ISO_9075.Fragment {
            ([
                partitions.isEmpty ? nil : "PARTITION BY \(partitions.joined(separator: ", "))",
                orderings.isEmpty ? nil : "ORDER BY \(orderings.joined(separator: ", "))",
                frame?.queryFragment,
            ] as [ISO_9075.Fragment?])
            .compactMap(\.self)
            .joined(separator: " ")
        }
    }
}

extension PostgreSQL.Window.Specification {
    public func partition(by expression: some QueryExpression) -> Self {
        Self(partitions: partitions + [expression.queryFragment], orderings: orderings, frame: frame)
    }

    public func partition(
        @QueryFragmentBuilder<()>
        by expressions: () -> [ISO_9075.Fragment]
    ) -> Self {
        Self(partitions: partitions + expressions(), orderings: orderings, frame: frame)
    }

    public func order(by expression: some QueryExpression) -> Self {
        Self(partitions: partitions, orderings: orderings + [expression.queryFragment], frame: frame)
    }

    public func order(
        @QueryFragmentBuilder<()>
        by expressions: () -> [ISO_9075.Fragment]
    ) -> Self {
        Self(partitions: partitions, orderings: orderings + expressions(), frame: frame)
    }

    public func framed(_ frame: PostgreSQL.Window.Frame) -> Self {
        Self(partitions: partitions, orderings: orderings, frame: frame)
    }

    public func rows(
        between start: PostgreSQL.Window.Frame.Bound,
        and end: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.rows, from: start, to: end, excluding: exclusion))
    }

    public func rows(
        _ start: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.rows, from: start, excluding: exclusion))
    }

    public func range(
        between start: PostgreSQL.Window.Frame.Bound,
        and end: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.range, from: start, to: end, excluding: exclusion))
    }

    public func range(
        _ start: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.range, from: start, excluding: exclusion))
    }

    public func groups(
        between start: PostgreSQL.Window.Frame.Bound,
        and end: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.groups, from: start, to: end, excluding: exclusion))
    }

    public func groups(
        _ start: PostgreSQL.Window.Frame.Bound,
        excluding exclusion: PostgreSQL.Window.Frame.Exclusion? = nil
    ) -> Self {
        framed(PostgreSQL.Window.Frame(.groups, from: start, excluding: exclusion))
    }
}
