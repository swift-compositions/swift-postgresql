public import Byte
public import ISO_9075_Foundation
public import RFC_4122
public import SQL
public import Time

extension PostgreSQL {
    public protocol DataType: QueryBindable {
        static var typeName: String { get }
        static var valueKind: ISO_9075.Value.Kind { get }
    }
}

extension PostgreSQL.DataType where Self: BinaryInteger {
    public static var typeName: String { "INTEGER" }

    public static var valueKind: ISO_9075.Value.Kind { .int }
}

extension PostgreSQL.DataType where Self: FloatingPoint {
    public static var typeName: String { "REAL" }

    public static var valueKind: ISO_9075.Value.Kind { .double }
}

extension Int: PostgreSQL.DataType {
    public static var typeName: String { "BIGINT" }
}

extension Int8: PostgreSQL.DataType {
    public static var typeName: String { "SMALLINT" }
}

extension Int16: PostgreSQL.DataType {
    public static var typeName: String { "SMALLINT" }
}

extension Int32: PostgreSQL.DataType {}

extension Int64: PostgreSQL.DataType {
    public static var typeName: String { "BIGINT" }
}

extension UInt8: PostgreSQL.DataType {
    public static var typeName: String { "SMALLINT" }
}

extension UInt16: PostgreSQL.DataType {}

extension UInt32: PostgreSQL.DataType {
    public static var typeName: String { "BIGINT" }
}

extension Float: PostgreSQL.DataType {}

extension Double: PostgreSQL.DataType {
    public static var typeName: String { "DOUBLE PRECISION" }
}

extension Bool: PostgreSQL.DataType {
    public static var typeName: String { "BOOLEAN" }

    public static var valueKind: ISO_9075.Value.Kind { .bool }
}

extension String: PostgreSQL.DataType {
    public static var typeName: String { "TEXT" }

    public static var valueKind: ISO_9075.Value.Kind { .text }
}

extension [Byte]: PostgreSQL.DataType {
    public static var typeName: String { "BYTEA" }

    public static var valueKind: ISO_9075.Value.Kind { .blob }
}

extension Time.Instant: PostgreSQL.DataType {
    public static var typeName: String { "TIMESTAMPTZ" }

    public static var valueKind: ISO_9075.Value.Kind { .timestamp }
}

extension RFC_4122.UUID: PostgreSQL.DataType {
    public static var typeName: String { "UUID" }

    public static var valueKind: ISO_9075.Value.Kind { .uuid }
}

extension Optional: PostgreSQL.DataType where Wrapped: PostgreSQL.DataType {
    public static var typeName: String { Wrapped.typeName }

    public static var valueKind: ISO_9075.Value.Kind { Wrapped.valueKind }
}

extension PostgreSQL.DataType where Self: RawRepresentable, RawValue: PostgreSQL.DataType {
    public static var typeName: String { RawValue.typeName }

    public static var valueKind: ISO_9075.Value.Kind { RawValue.valueKind }
}

extension QueryExpression where QueryValue: QueryBindable {
    public func cast<Other: PostgreSQL.DataType>(
        as _: Other.Type = Other.self
    ) -> some QueryExpression<Other> {
        SQLQueryExpression("CAST(\(self) AS \(raw: Other.typeName))", as: Other.self)
    }
}

extension QueryExpression where QueryValue: QueryBindable & _OptionalProtocol {
    public func cast<Other: _OptionalPromotable & PostgreSQL.DataType>(
        as _: Other.Type = Other.self
    ) -> some QueryExpression<Other._Optionalized>
    where Other._Optionalized: PostgreSQL.DataType {
        SQLQueryExpression("CAST(\(self) AS \(raw: Other.typeName))", as: Other._Optionalized.self)
    }
}

extension QueryExpression where QueryValue == Int {
    public func cast() -> some QueryExpression<Double> {
        cast(as: Double.self)
    }
}

extension QueryExpression where QueryValue == Int? {
    public func cast() -> some QueryExpression<Double?> {
        cast(as: Double.self)
    }
}
