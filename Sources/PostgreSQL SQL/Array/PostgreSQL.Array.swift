public import Byte
public import ISO_9075_Foundation
public import RFC_4122
public import SQL
public import Time

extension PostgreSQL {
    public struct Array<Element: QueryBindable & QueryDecodable> {
        public var elements: [Element.QueryOutput]

        public init(_ elements: [Element.QueryOutput]) {
            self.elements = elements
        }
    }
}

extension PostgreSQL.Array: Equatable where Element.QueryOutput: Equatable {}

extension PostgreSQL.Array: Hashable where Element.QueryOutput: Hashable {}

extension PostgreSQL.Array: Sendable where Element.QueryOutput: Sendable {}

extension PostgreSQL.Array: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element.QueryOutput...) {
        self.elements = elements
    }
}

extension PostgreSQL.Array: QueryRepresentable {
    public init(queryOutput: [Element.QueryOutput]) {
        self.elements = queryOutput
    }

    public var queryOutput: [Element.QueryOutput] { elements }
}

extension PostgreSQL.Array: QueryExpression, QueryBindable where Element: PostgreSQL.DataType {
    public var queryBinding: ISO_9075.Value {
        .array(elements.map { Element(queryOutput: $0).queryBinding }, of: Element.valueKind)
    }
}

extension PostgreSQL.Array: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let text = try String(decoder: &decoder)
        self.elements = try Literal(text).fields.map { field throws(QueryDecodingError) in
            var element = Field.Decoder(field: field)
            return try Element(decoder: &element).queryOutput
        }
    }
}

extension PostgreSQL.Array {
    public static func empty() -> some QueryExpression<Self> where Element: PostgreSQL.DataType {
        SQLQueryExpression("ARRAY[]::\(raw: Element.typeName)[]", as: Self.self)
    }

    public static func of<Elements: Sequence>(_ elements: Elements) -> some QueryExpression<Self>
    where Elements.Element: QueryExpression, Elements.Element.QueryValue == Element {
        SQLQueryExpression("ARRAY[\(elements.map(\.queryFragment).joined(separator: ", "))]", as: Self.self)
    }
}

extension PostgreSQL.Array {
    enum Field: Equatable {
        case null
        case text(String)
    }

    struct Literal {
        let fields: [Field]

        init(_ text: String) throws(QueryDecodingError) {
            var characters = text[...]
            guard characters.popFirst() == "{", characters.popLast() == "}" else {
                throw .dataCorrupted("\(text) as a one-dimensional array")
            }
            var fields: [Field] = []
            while !characters.isEmpty {
                fields.append(try Self.field(&characters, in: text))
                switch characters.popFirst() {
                case ",", nil: continue
                case let separator?: throw .dataCorrupted("\(separator) after an element of \(text)")
                }
            }
            self.fields = fields
        }

        private static func field(_ characters: inout Substring, in text: String) throws(QueryDecodingError) -> Field {
            guard characters.first == "\"" else {
                let unquoted = characters.prefix { $0 != "," }
                characters.removeFirst(unquoted.count)
                guard !unquoted.contains("{") else { throw .dataCorrupted("\(text) as a one-dimensional array") }
                return unquoted.uppercased() == "NULL" ? .null : .text(String(unquoted))
            }
            characters.removeFirst()
            var value = ""
            while let character = characters.popFirst() {
                switch character {
                case "\"": return .text(value)
                case "\\":
                    guard let escaped = characters.popFirst() else { throw .dataCorrupted("\(text) ends inside an escape") }
                    value.append(escaped)
                default: value.append(character)
                }
            }
            throw .dataCorrupted("\(text) ends inside a quoted element")
        }
    }
}

extension PostgreSQL.Array.Field {
    struct Decoder: QueryDecoder {
        var field: PostgreSQL.Array<Element>.Field

        private func text() -> String? {
            switch field {
            case .null: nil
            case .text(let text): text
            }
        }

        private func parsed<Value>(
            _ parse: (String) -> Value?,
            as _: Value.Type
        ) throws(QueryDecodingError) -> Value? {
            guard let text = text() else { return nil }
            guard let value = parse(text) else { throw .typeMismatch(expected: "\(Value.self), found \(text)") }
            return value
        }

        mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
            guard let text = text() else { return nil }
            guard text.hasPrefix("\\x"), text.count % 2 == 0 else { throw .dataCorrupted("\(text) as bytea") }
            let digits = Swift.Array(text.utf8.dropFirst(2))
            return try stride(from: 0, to: digits.count, by: 2).map { offset throws(QueryDecodingError) in
                guard let value = UInt8(String(decoding: digits[offset..<offset + 2], as: UTF8.self), radix: 16) else {
                    throw .dataCorrupted("\(text) as bytea")
                }
                return Byte(value)
            }
        }

        mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
            try parsed(Double.init, as: Double.self)
        }

        mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
            try parsed(
                { text in
                    switch text {
                    case "t", "true": 1
                    case "f", "false": 0
                    default: Int64(text)
                    }
                },
                as: Int64.self
            )
        }

        mutating func decode(_ columnType: UInt64.Type) throws(QueryDecodingError) -> UInt64? {
            try parsed(UInt64.init, as: UInt64.self)
        }

        mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
            text()
        }

        mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
            try decode(Int64.self).map { $0 != 0 }
        }

        mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
            try parsed(Int.init, as: Int.self)
        }

        mutating func decode(_ columnType: Time.Instant.Type) throws(QueryDecodingError) -> Time.Instant? {
            guard let text = text() else { return nil }
            do {
                return try ISO_9075.Literal.instant(text)
            } catch {
                throw .dataCorrupted("\(text) as a timestamp")
            }
        }

        mutating func decode(_ columnType: RFC_4122.UUID.Type) throws(QueryDecodingError) -> RFC_4122.UUID? {
            guard let text = text() else { return nil }
            do {
                return try RFC_4122.UUID(text)
            } catch {
                throw .dataCorrupted("\(text) as a UUID")
            }
        }
    }
}
