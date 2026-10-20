#if Tagged
public import ISO_9075_Foundation
public import SQL
public import Tagged

extension Tagged: PostgreSQL.DataType
where Tag: ~Copyable & ~Escapable, Underlying: PostgreSQL.DataType {
    public static var typeName: String { Underlying.typeName }

    public static var valueKind: ISO_9075.Value.Kind { Underlying.valueKind }
}
#endif
