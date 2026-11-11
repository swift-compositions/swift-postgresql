#if PostgresNIO && !os(Windows)
    public import PostgreSQL_SQL
    internal import Byte
    internal import Foundation
    public import ISO_9075_Call_Level_Interface
    internal import NIOCore
    package import PostgresNIO
    internal import RFC_4122
    internal import Time

    extension PostgreSQL {
        public struct Row: ISO_9075.Row, Sendable {
            let cells: [PostgresCell]

            package init(_ row: PostgresRow) {
                self.cells = Swift.Array(row)
            }

            public var columns: [String] { cells.map(\.columnName) }

            public func value(at index: Int) throws(ISO_9075.Error) -> ISO_9075.Value {
                guard cells.indices.contains(index) else { throw .decoding("no column \(index)") }
                return try cells[index].value
            }
        }
    }

    extension PostgresCell {
        var value: ISO_9075.Value {
            get throws(ISO_9075.Error) {
                guard bytes != nil else { return .null }
                return switch dataType {
                case .bool: .bool(try decoded(Bool.self))
                case .int2, .int4, .int8, .oid: .int(try decoded(Int64.self))
                case .float4, .float8: .double(try decoded(Double.self))
                case .numeric: .decimal(try decoded(Decimal.self).description)
                case .bytea: .blob(try decoded(ByteBuffer.self).readableBytesView.map(Byte.init(bitPattern:)))
                case .timestamp, .timestamptz, .date: .timestamp(try decoded(PostgresInstant.self).instant)
                case .uuid: .uuid(RFC_4122.UUID(bytes: try decoded(Foundation.UUID.self).uuid))
                case .json, .jsonb: .json(try decoded(String.self).utf8.map(Byte.init(bitPattern:)))
                case .boolArray, .int2Array, .int4Array, .int8Array, .float4Array, .float8Array, .textArray, .varcharArray,
                    .bpcharArray, .nameArray, .uuidArray, .timestampArray, .timestamptzArray, .dateArray:
                    .text(try arrayLiteral)
                default: .text(try decoded(String.self))
                }
            }
        }

        func decoded<Value: PostgresDecodable>(_ type: Value.Type) throws(ISO_9075.Error) -> Value {
            do {
                return try decode(Value.self)
            } catch {
                throw .decoding("column \(columnIndex) (\(columnName)) as \(Value.self): \(error)")
            }
        }

        var arrayLiteral: String {
            get throws(ISO_9075.Error) {
                func literal<Element: PostgresArrayDecodable>(
                    _ type: Element.Type,
                    _ field: (Element) throws(ISO_9075.Error) -> String
                ) throws(ISO_9075.Error) -> String where Element == Element._DecodableType {
                    "{" + (try decoded([Element].self).map(field)).joined(separator: ",") + "}"
                }
                return switch dataType {
                case .boolArray: try literal(Bool.self) { $0 ? "t" : "f" }
                case .int2Array, .int4Array, .int8Array: try literal(Int64.self) { "\($0)" }
                case .float4Array, .float8Array: try literal(Double.self) { "\($0)" }
                case .uuidArray: try literal(Foundation.UUID.self) { $0.uuidString.lowercased() }
                case .timestampArray, .timestamptzArray, .dateArray:
                    try literal(PostgresInstant.self) { instant throws(ISO_9075.Error) in
                        let instant = instant.instant
                        do {
                            return PostgresCell.quoted(try ISO_9075.Literal.timestamp(instant))
                        } catch {
                            throw .decoding("\(instant) as a timestamp: \(error)")
                        }
                    }
                default: try literal(String.self) { PostgresCell.quoted($0) }
                }
            }
        }

        static func quoted(_ text: String) -> String {
            "\"" + text.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"") + "\""
        }
    }
#endif
