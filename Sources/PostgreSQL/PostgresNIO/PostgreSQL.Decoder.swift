public import PostgreSQL_SQL
#if PostgresNIO
    public import Byte
    public import ISO_9075_Call_Level_Interface
    public import RFC_4122
    public import SQL
    public import Time

    extension PostgreSQL {
        public struct Decoder: QueryDecoder {
            let row: PostgreSQL.Row
            var index = 0

            public init(row: PostgreSQL.Row) {
                self.row = row
            }

            private mutating func next<Value>(
                _ convert: (ISO_9075.Value) -> Value?
            ) throws(QueryDecodingError) -> Value? {
                defer { index += 1 }
                let value: ISO_9075.Value
                do {
                    value = try row.value(at: index)
                } catch {
                    throw .dataCorrupted("\(error)")
                }
                guard value != .null else { return nil }
                guard let converted = convert(value) else {
                    throw .typeMismatch(expected: "\(Value.self) in column \(index), found \(value)")
                }
                return converted
            }

            public mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
                try next { value in
                    switch value {
                    case .blob(let bytes), .json(let bytes): bytes
                    case .text(let text): text.utf8.map(Byte.init(bitPattern:))
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
                try next { value in
                    switch value {
                    case .double(let double): double
                    case .int(let int): Double(int)
                    case .decimal(let digits): Double(digits)
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
                try next { value in
                    switch value {
                    case .int(let int): int
                    case .bool(let bool): bool ? 1 : 0
                    case .decimal(let digits): Int64(digits)
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: UInt64.Type) throws(QueryDecodingError) -> UInt64? {
                try decode(Int64.self).map { value throws(QueryDecodingError) in
                    guard let unsigned = UInt64(exactly: value) else { throw .overflow("\(value) as UInt64") }
                    return unsigned
                }
            }

            public mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
                try next { value in
                    switch value {
                    case .text(let text), .decimal(let text): text
                    case .json(let bytes): String(decoding: bytes.map(\.underlying), as: UTF8.self)
                    case .uuid(let uuid): String(uuid).lowercased()
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
                try next { value in
                    switch value {
                    case .bool(let bool): bool
                    case .int(let int): int != 0
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
                try decode(Int64.self).map { value throws(QueryDecodingError) in
                    guard let int = Int(exactly: value) else { throw .overflow("\(value) as Int") }
                    return int
                }
            }

            public mutating func decode(_ columnType: Time.Instant.Type) throws(QueryDecodingError) -> Time.Instant? {
                try next { value in
                    switch value {
                    case .timestamp(let instant): instant
                    case .text(let text): try? ISO_9075.Literal.instant(text)
                    default: nil
                    }
                }
            }

            public mutating func decode(_ columnType: RFC_4122.UUID.Type) throws(QueryDecodingError) -> RFC_4122.UUID? {
                try next { value in
                    switch value {
                    case .uuid(let uuid): uuid
                    case .text(let text): try? RFC_4122.UUID(text)
                    default: nil
                    }
                }
            }
        }
    }
#endif
