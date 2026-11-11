public import PostgreSQL_SQL
#if PostgresNIO && !os(Windows)
    internal import Byte
    internal import Foundation
    package import ISO_9075_Call_Level_Interface
    package import NIOCore
    package import PostgresNIO
    internal import RFC_4122
    package import Time

    extension PostgresQuery {
        /// The engine's query for a rendering: its SQL, and each value bound in order.
        package init(_ rendering: ISO_9075.Rendering) throws(ISO_9075.Error) {
            var bindings = PostgresBindings(capacity: rendering.values.count)
            for value in rendering.values {
                try value.bind(to: &bindings)
            }
            self.init(unsafeSQL: rendering.sql, binds: bindings)
        }
    }

    extension ISO_9075.Value {
        func bind(to bindings: inout PostgresBindings) throws(ISO_9075.Error) {
            switch self {
            case .null: bindings.appendNull()
            case .bool(let bool): bindings.append(bool)
            case .int(let int): bindings.append(int)
            case .double(let double): bindings.append(double)
            case .text(let text): bindings.append(text)
            case .blob(let bytes): bindings.append(ByteBuffer(bytes: bytes.map(\.underlying)))
            case .timestamp(let instant): bindings.append(PostgresInstant(instant))
            case .uuid(let uuid): bindings.append(Foundation.UUID(uuid: uuid.bytes))
            case .json(let bytes): bindings.append(PostgresData(jsonb: Data(bytes.map(\.underlying))))
            case .decimal(let digits):
                guard digits.wholeMatch(of: /[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?|NaN|[+-]?Infinity/) != nil else {
                    throw .binding(ISO_9075.Value.Failure("\(digits) is not a decimal"))
                }
                bindings.append(PostgresData(type: .numeric, formatCode: .text, value: ByteBuffer(string: digits)))
            case .array(let values, let kind): try ISO_9075.Value.bind(array: values, of: kind, to: &bindings)
            case .invalid(let failure): throw .binding(failure)
            }
        }

        private static func bind(
            array values: [ISO_9075.Value],
            of kind: ISO_9075.Value.Kind,
            to bindings: inout PostgresBindings
        ) throws(ISO_9075.Error) {
            func homogeneous<Element>(_ element: (ISO_9075.Value) -> Element?) throws(ISO_9075.Error) -> [Element] {
                let elements = values.compactMap(element)
                guard elements.count == values.count else {
                    throw .binding(ISO_9075.Value.Failure("PostgreSQL arrays of \(kind) hold only \(kind) elements and no nulls when bound: \(values)"))
                }
                return elements
            }
            switch kind {
            case .bool:
                bindings.append(try homogeneous { if case .bool(let bool) = $0 { bool } else { nil } })
            case .int:
                bindings.append(try homogeneous { if case .int(let int) = $0 { int } else { nil } })
            case .double:
                bindings.append(try homogeneous { if case .double(let double) = $0 { double } else { nil } })
            case .text:
                bindings.append(try homogeneous { if case .text(let text) = $0 { text } else { nil } })
            case .blob:
                bindings.append(try homogeneous { if case .blob(let bytes) = $0 { ByteBuffer(bytes: bytes.map(\.underlying)) } else { nil } })
            case .uuid:
                bindings.append(try homogeneous { if case .uuid(let uuid) = $0 { Foundation.UUID(uuid: uuid.bytes) } else { nil } })
            case .timestamp:
                bindings.append(try homogeneous { if case .timestamp(let instant) = $0 { PostgresInstant(instant) } else { nil } })
            case .decimal, .json:
                throw .binding(ISO_9075.Value.Failure("PostgreSQL has no array binding for \(kind)"))
            }
        }
    }

    /// An instant as the engine binds and decodes it: microseconds since 2000-01-01 UTC, as `timestamptz`.
    ///
    /// A type of the package's own, so that `Time.Instant` never conforms to the engine's protocols in public.
    package struct PostgresInstant: Sendable {
        package let instant: Time.Instant

        package init(_ instant: Time.Instant) {
            self.instant = instant
        }
    }

    extension PostgresInstant: PostgresNonThrowingEncodable, PostgresArrayEncodable {
        package static var psqlType: PostgresDataType { .timestamptz }

        package static var psqlFormat: PostgresFormat { .binary }

        package static var psqlArrayType: PostgresDataType { .timestamptzArray }

        package func encode<JSONEncoder: PostgresJSONEncoder>(
            into byteBuffer: inout ByteBuffer,
            context: PostgresEncodingContext<JSONEncoder>
        ) {
            byteBuffer.writeInteger(
                (instant.secondsSinceUnixEpoch - PostgresInstant.postgresEpoch) * 1_000_000
                    + Int64(instant.nanosecondFraction / 1_000)
            )
        }
    }

    extension PostgresInstant: PostgresDecodable, PostgresArrayDecodable {
        package init<JSONDecoder: PostgresJSONDecoder>(
            from buffer: inout ByteBuffer,
            type: PostgresDataType,
            format: PostgresFormat,
            context: PostgresDecodingContext<JSONDecoder>
        ) throws {
            switch (type, format) {
            case (.timestamptz, .binary), (.timestamp, .binary):
                guard buffer.readableBytes == 8, let microseconds = buffer.readInteger(as: Int64.self) else {
                    throw PostgresDecodingError.Code.failure
                }
                let (seconds, remainder) = microseconds.quotientAndRemainder(dividingBy: 1_000_000)
                self.init(
                    Time.Instant(
                        _unchecked: (),
                        secondsSinceUnixEpoch: PostgresInstant.postgresEpoch + seconds - (remainder < 0 ? 1 : 0),
                        nanosecondFraction: Int32((remainder < 0 ? remainder + 1_000_000 : remainder) * 1_000)
                    )
                )
            case (.date, .binary):
                guard buffer.readableBytes == 4, let days = buffer.readInteger(as: Int32.self) else {
                    throw PostgresDecodingError.Code.failure
                }
                self.init(Time.Instant(secondsSinceUnixEpoch: PostgresInstant.postgresEpoch + Int64(days) * 86_400))
            default:
                throw PostgresDecodingError.Code.typeMismatch
            }
        }

        static let postgresEpoch: Int64 = 946_684_800
    }
#endif
