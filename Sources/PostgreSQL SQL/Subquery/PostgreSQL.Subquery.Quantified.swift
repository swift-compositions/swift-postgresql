internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL.Subquery {
    public struct Quantified<Value>: Sendable {
        public let quantifier: Quantifier
        let source: ISO_9075.Fragment

        init(_ quantifier: Quantifier, _ source: ISO_9075.Fragment) {
            self.quantifier = quantifier
            self.source = source
        }

        var queryFragment: ISO_9075.Fragment {
            "\(raw: quantifier.rawValue) (\(source))"
        }
    }
}

extension PostgreSQL.Subquery.Quantified {
    public static func `any`(_ subquery: some Statement<Value>) -> Self {
        Self(.any, subquery.query)
    }

    public static func all(_ subquery: some Statement<Value>) -> Self {
        Self(.all, subquery.query)
    }

    public static func `some`(_ subquery: some Statement<Value>) -> Self {
        Self(.some, subquery.query)
    }
}

extension PostgreSQL.Subquery.Quantified where Value: QueryBindable & QueryDecodable {
    public static func `any`(_ array: some QueryExpression<PostgreSQL.Array<Value>>) -> Self {
        Self(.any, array.queryFragment)
    }

    public static func all(_ array: some QueryExpression<PostgreSQL.Array<Value>>) -> Self {
        Self(.all, array.queryFragment)
    }

    public static func `some`(_ array: some QueryExpression<PostgreSQL.Array<Value>>) -> Self {
        Self(.some, array.queryFragment)
    }
}
