public import Byte
internal import Foundation
public import ISO_9075_Foundation
public import SQL
internal import Time

extension PostgreSQL {
    public struct JSONB<Value: Codable>: QueryRepresentable {
        public var queryOutput: Value

        public init(queryOutput: Value) {
            self.queryOutput = queryOutput
        }
    }
}

extension PostgreSQL.JSONB: Equatable where Value: Equatable {}

extension PostgreSQL.JSONB: Hashable where Value: Hashable {}

extension PostgreSQL.JSONB: Sendable where Value: Sendable {}

extension PostgreSQL.JSONB: QueryBindable {
    public var queryBinding: ISO_9075.Value {
        do {
            return .json(try Self.encoder.encode(queryOutput).map(Byte.init(bitPattern:)))
        } catch {
            return .invalid(ISO_9075.Value.Failure(error))
        }
    }
}

extension PostgreSQL.JSONB: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        try self.init(text: try String(decoder: &decoder))
    }
}

extension PostgreSQL.JSONB {
    init(text: String) throws(QueryDecodingError) {
        do {
            self.init(queryOutput: try Self.decoder.decode(Value.self, from: Data(text.utf8)))
        } catch {
            throw .dataCorrupted("\(text) as JSONB \(Value.self)")
        }
    }

    var textBinding: ISO_9075.Value {
        do {
            return .text(String(decoding: try Self.encoder.encode(queryOutput), as: UTF8.self))
        } catch {
            return .invalid(ISO_9075.Value.Failure(error))
        }
    }
}

extension PostgreSQL.JSONB {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestamp = try container.decode(String.self)
            do {
                let instant = try PostgreSQL.JSON.instant(timestamp)
                return Date(
                    timeIntervalSince1970: Double(instant.secondsSinceUnixEpoch) + Double(instant.nanosecondFraction) / 1_000_000_000
                )
            } catch {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(timestamp) is not a timestamp: \(error)")
            }
        }
        return decoder
    }
}
