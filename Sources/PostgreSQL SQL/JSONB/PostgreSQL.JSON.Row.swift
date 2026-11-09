public import Byte
internal import Foundation
internal import ISO_9075_Foundation
public import RFC_4122
public import SQL
public import Time

extension PostgreSQL.JSON {
    public struct Row: QueryDecoder {
        var values: IndexingIterator<[Any?]>

        public init<On: Table>(_ text: String, as table: On.Type) throws(QueryDecodingError) {
            self.init(try PostgreSQL.JSON.object(text), as: table)
        }

        init<On: Table>(_ object: [String: Any], as _: On.Type) {
            self.values = On.TableColumns.allColumns
                .map { column in object[column.name].flatMap { $0 is NSNull ? nil : $0 } }
                .makeIterator()
        }

        mutating func next() throws(QueryDecodingError) -> Any? {
            guard let value = values.next() else { throw .missingRequiredColumn }
            return value
        }

        mutating func next<Value>(_ convert: (Any) -> Value?) throws(QueryDecodingError) -> Value? {
            guard let value = try next() else { return nil }
            guard let converted = convert(value) else { throw .typeMismatch(expected: "\(Value.self), found \(value)") }
            return converted
        }

        public mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
            guard let text = try next({ $0 as? String }) else { return nil }
            let digits = Array(text.utf8.dropFirst(2))
            guard text.hasPrefix("\\x"), digits.count % 2 == 0 else { throw .dataCorrupted("\(text) as bytea") }
            return try stride(from: 0, to: digits.count, by: 2).map { offset throws(QueryDecodingError) in
                guard let value = UInt8(String(decoding: digits[offset..<offset + 2], as: UTF8.self), radix: 16) else {
                    throw .dataCorrupted("\(text) as bytea")
                }
                return Byte(bitPattern: value)
            }
        }

        public mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
            try next { ($0 as? NSNumber)?.doubleValue }
        }

        public mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
            try next { ($0 as? NSNumber)?.int64Value }
        }

        public mutating func decode(_ columnType: UInt64.Type) throws(QueryDecodingError) -> UInt64? {
            try next { ($0 as? NSNumber)?.uint64Value }
        }

        public mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
            try next { value in
                (value as? String)
                    ?? (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]))
                    .map { String(decoding: $0, as: UTF8.self) }
            }
        }

        public mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
            try next { $0 as? Bool }
        }

        public mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
            try next { ($0 as? NSNumber)?.intValue }
        }

        public mutating func decode(_ columnType: Time.Instant.Type) throws(QueryDecodingError) -> Time.Instant? {
            guard let text = try next({ $0 as? String }) else { return nil }
            do {
                return try PostgreSQL.JSON.instant(text)
            } catch {
                throw .dataCorrupted("\(text) as a timestamp: \(error)")
            }
        }

        public mutating func decode(_ columnType: RFC_4122.UUID.Type) throws(QueryDecodingError) -> RFC_4122.UUID? {
            guard let text = try next({ $0 as? String }) else { return nil }
            do {
                return try RFC_4122.UUID(text)
            } catch {
                throw .dataCorrupted("\(text) as a UUID")
            }
        }
    }
}

extension PostgreSQL.JSON {
    static func object(_ text: String) throws(QueryDecodingError) -> [String: Any] {
        guard
            let data = text.data(using: .utf8),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            throw .dataCorrupted("\(text) is not a JSON object")
        }
        return object
    }

    static func instant(_ text: String) throws(ISO_9075.Value.Failure) -> Time.Instant {
        let time = text.firstIndex(of: "T").map { text[$0...] } ?? text[text.endIndex...]
        let sign = time.lastIndex { $0 == "+" || $0 == "-" }
        let local = sign.map { text[..<$0] } ?? text[...]
        let offset = try sign.map { index throws(ISO_9075.Value.Failure) in try offsetSeconds(text[index...]) } ?? 0
        let instant = try ISO_9075.Literal.instant(local.contains("T") ? String(local) : local + "T00:00:00")
        return Time.Instant(
            _unchecked: (),
            secondsSinceUnixEpoch: instant.secondsSinceUnixEpoch - offset,
            nanosecondFraction: instant.nanosecondFraction
        )
    }

    private static func offsetSeconds(_ offset: Substring) throws(ISO_9075.Value.Failure) -> Int64 {
        let fields: [Int?] = offset.dropFirst().split(separator: ":").map { Int($0) }
        guard (1...2).contains(fields.count), let hours = fields[0], let minutes = fields.count == 2 ? fields[1] : 0 else {
            throw ISO_9075.Value.Failure("\(offset) is not a time zone offset")
        }
        let seconds = Int64(hours) * 3_600 + Int64(minutes) * 60
        return offset.first == "-" ? -seconds : seconds
    }
}
