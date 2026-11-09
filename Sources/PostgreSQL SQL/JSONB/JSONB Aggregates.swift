public import Byte
public import ISO_9075_Foundation
public import SQL

extension QueryExpression {
    public func jsonAgg(
        distinct isDistinct: Bool = false,
        order: (some QueryExpression)? = Bool?.none,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> PostgreSQL.Aggregate<[Byte]?> {
        PostgreSQL.Aggregate<[Byte]?>(
            "json_agg",
            distinct: isDistinct,
            [queryFragment],
            order: order?.queryFragment,
            filter: filter?.queryFragment
        )
    }

    public func jsonbAgg(
        distinct isDistinct: Bool = false,
        order: (some QueryExpression)? = Bool?.none,
        filter: (some QueryExpression<Bool>)? = Bool?.none
    ) -> PostgreSQL.Aggregate<[Byte]?> {
        PostgreSQL.Aggregate<[Byte]?>(
            "jsonb_agg",
            distinct: isDistinct,
            [queryFragment],
            order: order?.queryFragment,
            filter: filter?.queryFragment
        )
    }
}

extension Table {
    public static func jsonbAgg(
        of expression: (TableColumns) -> some QueryExpression
    ) -> Select<[Byte]?, Self, ()> {
        Self.all.asSelect().select { _ in expression(columns).jsonbAgg() }
    }

    public static func jsonbAgg<Expression: QueryExpression, Filter: QueryExpression<Bool>>(
        of expression: (TableColumns) -> Expression,
        filter: (TableColumns) -> Filter
    ) -> Select<[Byte]?, Self, ()> {
        Self.all.asSelect().select { _ in expression(columns).jsonbAgg(filter: filter(columns)) }
    }
}

extension Where {
    public func jsonbAgg(
        of expression: (From.TableColumns) -> some QueryExpression
    ) -> Select<[Byte]?, From, ()> {
        asSelect().select { _ in expression(From.columns).jsonbAgg() }
    }

    public func jsonbAgg<Expression: QueryExpression, Filter: QueryExpression<Bool>>(
        of expression: (From.TableColumns) -> Expression,
        filter: (From.TableColumns) -> Filter
    ) -> Select<[Byte]?, From, ()> {
        asSelect().select { _ in expression(From.columns).jsonbAgg(filter: filter(From.columns)) }
    }
}
