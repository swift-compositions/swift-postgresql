public import Byte
public import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: PostgreSQL.JSON.Document {
    public func field(_ key: String) -> some QueryExpression<[Byte]?> {
        SQLQueryExpression("(\(self) -> \(bind: key))", as: [Byte]?.self)
    }

    public func fieldAsText(_ key: String) -> some QueryExpression<String?> {
        SQLQueryExpression("(\(self) ->> \(bind: key))", as: String?.self)
    }

    public func element(at index: Int) -> some QueryExpression<[Byte]?> {
        SQLQueryExpression("(\(self) -> \(bind: index)::integer)", as: [Byte]?.self)
    }

    public func elementAsText(at index: Int) -> some QueryExpression<String?> {
        SQLQueryExpression("(\(self) ->> \(bind: index)::integer)", as: String?.self)
    }

    public func value(at path: [String]) -> some QueryExpression<[Byte]?> {
        SQLQueryExpression("(\(self) #> \(PostgreSQL.JSON.textArray(path)))", as: [Byte]?.self)
    }

    public func valueAsText(at path: [String]) -> some QueryExpression<String?> {
        SQLQueryExpression("(\(self) #>> \(PostgreSQL.JSON.textArray(path)))", as: String?.self)
    }

    public func contains(_ value: some Codable) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) @> \(PostgreSQL.JSON.document(value)))", as: Bool.self)
    }

    public func isContained(by value: some Codable) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) <@ \(PostgreSQL.JSON.document(value)))", as: Bool.self)
    }

    public func hasKey(_ key: String) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) ? \(bind: key))", as: Bool.self)
    }

    public func hasAny(of keys: [String]) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) ?| \(PostgreSQL.JSON.textArray(keys)))", as: Bool.self)
    }

    public func hasAll(of keys: [String]) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) ?& \(PostgreSQL.JSON.textArray(keys)))", as: Bool.self)
    }

    public func concat(_ value: some Codable) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) || \(PostgreSQL.JSON.document(value)))", as: QueryValue.self)
    }

    public func removing(_ key: String) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) - \(bind: key))", as: QueryValue.self)
    }

    public func removing(keys: [String]) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) - \(PostgreSQL.JSON.textArray(keys)))", as: QueryValue.self)
    }

    public func removing(at index: Int) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) - \(bind: index)::integer)", as: QueryValue.self)
    }

    public func removing(path: [String]) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("(\(self) #- \(PostgreSQL.JSON.textArray(path)))", as: QueryValue.self)
    }

    public func jsonPathExists(_ path: String) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) @? \(bind: path)::jsonpath)", as: Bool.self)
    }

    public func jsonPathMatch(_ path: String) -> some QueryExpression<Bool> {
        SQLQueryExpression("(\(self) @@ \(bind: path)::jsonpath)", as: Bool.self)
    }
}
