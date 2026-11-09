internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: PostgreSQL.TextSearch.Document {
    public func matches(_ query: some QueryExpression<PostgreSQL.TextSearch.Query>) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) @@ \(query))", as: Bool.self)
    }

    public func rank(
        _ query: some QueryExpression<PostgreSQL.TextSearch.Query>,
        normalization: PostgreSQL.TextSearch.Normalization = []
    ) -> some QueryExpression<Double> {
        SQLQueryExpression("ts_rank(\(self), \(query), \(raw: normalization.rawValue))", as: Double.self)
    }

    public func coverDensityRank(
        _ query: some QueryExpression<PostgreSQL.TextSearch.Query>,
        normalization: PostgreSQL.TextSearch.Normalization = []
    ) -> some QueryExpression<Double> {
        SQLQueryExpression("ts_rank_cd(\(self), \(query), \(raw: normalization.rawValue))", as: Double.self)
    }

    public func weighted(_ weight: PostgreSQL.TextSearch.Weight) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("setweight(\(self), \(text: weight.rawValue))", as: QueryValue.self)
    }

    public func stripped() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("strip(\(self))", as: QueryValue.self)
    }

    public func lexemeCount() -> some QueryExpression<Int?> {
        SQLQueryExpression("length(\(self))", as: Int?.self)
    }

    public func concatenated(
        with other: some QueryExpression<some PostgreSQL.TextSearch.Document>
    ) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) || \(other))", as: QueryValue.self)
    }
}

extension QueryExpression where QueryValue == PostgreSQL.TextSearch.Query {
    public func and(_ other: some QueryExpression<PostgreSQL.TextSearch.Query>) -> some QueryExpression<PostgreSQL.TextSearch.Query> {
        SQLQueryExpression("(\(self) && \(other))", as: PostgreSQL.TextSearch.Query.self)
    }

    public func or(_ other: some QueryExpression<PostgreSQL.TextSearch.Query>) -> some QueryExpression<PostgreSQL.TextSearch.Query> {
        SQLQueryExpression("(\(self) || \(other))", as: PostgreSQL.TextSearch.Query.self)
    }

    public func negated() -> some QueryExpression<PostgreSQL.TextSearch.Query> {
        SQLQueryExpression("(!! \(self))", as: PostgreSQL.TextSearch.Query.self)
    }

    public func followed(
        by other: some QueryExpression<PostgreSQL.TextSearch.Query>,
        distance: Int = 1
    ) -> some QueryExpression<PostgreSQL.TextSearch.Query> {
        precondition(distance >= 0, "a phrase distance must not be negative, got \(distance)")
        return SQLQueryExpression("tsquery_phrase(\(self), \(other), \(raw: distance))", as: PostgreSQL.TextSearch.Query.self)
    }
}

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
    public func matches(
        _ query: some QueryExpression<PostgreSQL.TextSearch.Query>,
        configuration: PostgreSQL.TextSearch.Configuration
    ) -> some QueryExpression<Bool> {
        SQLQueryExpression(
            "(to_tsvector(\(configuration.queryFragment), \(self)) @@ \(query))",
            as: Bool.self
        )
    }

    public func headline(
        _ query: some QueryExpression<PostgreSQL.TextSearch.Query>,
        configuration: PostgreSQL.TextSearch.Configuration,
        options: PostgreSQL.TextSearch.Headline = PostgreSQL.TextSearch.Headline()
    ) -> some QueryExpression<QueryValue> {
        let options: ISO_9075.Fragment = options.text.map { ", \(bind: $0)" } ?? ""
        return SQLQueryExpression(
            "ts_headline(\(configuration.queryFragment), \(self), \(query)\(options))",
            as: QueryValue.self
        )
    }
}
