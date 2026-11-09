public import Byte
internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue == [Byte] {
    public func encode(_ encoding: PostgreSQL.Binary.Encoding) -> some QueryExpression<String> {
        SQLQueryExpression("encode(\(self), \(text: encoding.rawValue))", as: String.self)
    }
}

extension QueryExpression where QueryValue == String {
    public func decode(_ encoding: PostgreSQL.Binary.Encoding) -> some QueryExpression<[Byte]> {
        SQLQueryExpression("decode(\(self), \(text: encoding.rawValue))", as: [Byte].self)
    }
}
