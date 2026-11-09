internal import Byte
public import ISO_9075_Foundation
internal import RFC_4122
internal import Time

public struct PostgreSQL: ISO_9075.Dialect {
    public init() {}

    public func placeholder(_ offset: Int) -> String { "$\(offset)" }

    public func literal(_ value: ISO_9075.Value) throws(ISO_9075.Value.Failure) -> String {
        switch value {
        case .timestamp(let instant):
            "TIMESTAMPTZ " + ISO_9075.Literal.character(try ISO_9075.Literal.timestamp(instant) + "+00")
        case .blob(let bytes):
            ISO_9075.Literal.character(
                "\\x"
                    + bytes.map { byte in
                        let hex = String(byte.bitPattern, radix: 16)
                        return hex.count == 1 ? "0" + hex : hex
                    }.joined()
            ) + "::BYTEA"
        case .array(let values, let kind):
            "ARRAY[" + (try values.map { value throws(ISO_9075.Value.Failure) in try literal(value) }).joined(separator: ", ") + "]::"
                + typeName(kind) + "[]"
        default:
            try value.literal
        }
    }

    public var roundOpen: String { "CAST(" }

    public var roundClose: String { " AS DOUBLE PRECISION)" }

    public var roundOperandOpen: String { "CAST(" }

    public var roundOperandClose: String { " AS NUMERIC)" }

    public var roundPrecisionOpen: String { "CAST(" }

    public var roundPrecisionClose: String { " AS INTEGER)" }

    private func typeName(_ kind: ISO_9075.Value.Kind) -> String {
        switch kind {
        case .bool: Bool.typeName
        case .int: Int64.typeName
        case .double: Double.typeName
        case .text: String.typeName
        case .blob: [Byte].typeName
        case .timestamp: Time.Instant.typeName
        case .uuid: RFC_4122.UUID.typeName
        case .decimal: "NUMERIC"
        case .json: "JSONB"
        }
    }
}
