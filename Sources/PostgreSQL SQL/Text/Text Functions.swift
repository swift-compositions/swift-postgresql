internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: _OptionalPromotable<String?> {
    public func initcap() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("initcap(\(self))", as: QueryValue.self)
    }

    public func quoteNullable() -> some QueryExpression<String> {
        SQLQueryExpression("quote_nullable(\(self))", as: String.self)
    }
}

extension QueryExpression where QueryValue == String {
    public func charLength() -> some QueryExpression<Int> {
        SQLQueryExpression("char_length(\(self))", as: Int.self)
    }

    public func bitLength() -> some QueryExpression<Int> {
        SQLQueryExpression("bit_length(\(self))", as: Int.self)
    }

    public func lpad(to length: Int, with fill: String = " ") -> some QueryExpression<String> {
        SQLQueryExpression("lpad(\(self), \(raw: length), \(bind: fill))", as: String.self)
    }

    public func rpad(to length: Int, with fill: String = " ") -> some QueryExpression<String> {
        SQLQueryExpression("rpad(\(self), \(raw: length), \(bind: fill))", as: String.self)
    }

    public func left(_ count: Int) -> some QueryExpression<String> {
        SQLQueryExpression("left(\(self), \(raw: count))", as: String.self)
    }

    public func right(_ count: Int) -> some QueryExpression<String> {
        SQLQueryExpression("right(\(self), \(raw: count))", as: String.self)
    }

    public func splitPart(delimiter: String, field: Int) -> some QueryExpression<String> {
        SQLQueryExpression("split_part(\(self), \(bind: delimiter), \(raw: field))", as: String.self)
    }

    public func position(of substring: some QueryExpression<String>) -> some QueryExpression<Int> {
        SQLQueryExpression("position(\(substring) IN \(self))", as: Int.self)
    }

    public func startsWith(_ prefix: some QueryExpression<String>) -> some QueryExpression<Bool> {
        SQLQueryExpression("starts_with(\(self), \(prefix))", as: Bool.self)
    }

    public func translate(from: String, to: String) -> some QueryExpression<String> {
        SQLQueryExpression("translate(\(self), \(bind: from), \(bind: to))", as: String.self)
    }

    public func overlay(
        placing replacement: some QueryExpression<String>,
        from position: Int,
        for length: Int? = nil
    ) -> some QueryExpression<String> {
        let count: ISO_9075.Fragment = length.map { " FOR \(raw: $0)" } ?? ""
        return SQLQueryExpression(
            "overlay(\(self) PLACING \(replacement) FROM \(raw: position)\(count))",
            as: String.self
        )
    }

    @_disfavoredOverload
    public func reversed() -> some QueryExpression<String> {
        SQLQueryExpression("reverse(\(self))", as: String.self)
    }

    public func repeated(_ times: Int) -> some QueryExpression<String> {
        SQLQueryExpression("repeat(\(self), \(raw: times))", as: String.self)
    }

    public func md5() -> some QueryExpression<String> {
        SQLQueryExpression("md5(\(self))", as: String.self)
    }

    public func ascii() -> some QueryExpression<Int?> {
        SQLQueryExpression("ascii(\(self))", as: Int?.self)
    }

    public func quoteLiteral() -> some QueryExpression<String> {
        SQLQueryExpression("quote_literal(\(self))", as: String.self)
    }

    public func quoteIdent() -> some QueryExpression<String> {
        SQLQueryExpression("quote_ident(\(self))", as: String.self)
    }
}

extension QueryExpression where QueryValue == String? {
    public func charLength() -> some QueryExpression<Int?> {
        SQLQueryExpression("char_length(\(self))", as: Int?.self)
    }

    public func bitLength() -> some QueryExpression<Int?> {
        SQLQueryExpression("bit_length(\(self))", as: Int?.self)
    }
}
