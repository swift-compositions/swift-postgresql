#if PostgresNIO && !os(Windows)
    import Byte
    import ISO_9075_Foundation
    import PostgreSQL
    import RFC_4122
    import SQL
    import SQL_Macros
    import Time

    enum LiveFixtures {
        @Table("samples")
        struct Sample: Equatable, Sendable {
            let id: Int
            var count: Int
            var ratio: Double
            var isActive: Bool
            var name: String
            var bytes: [Byte]
            var createdAt: Time.Instant
            var reference: RFC_4122.UUID
            @Column(as: PostgreSQL.JSONB<[String: Int]>.self)
            var settings: [String: Int]
            @Column(as: PostgreSQL.Array<String>.self)
            var tags: [String]
            var note: String?
        }

        @Table("accounts")
        struct Account: Equatable, Sendable {
            let id: Int
            var owner: String
            var balance: Int
        }

        @Table("scores")
        struct Score: Equatable, Sendable {
            let id: Int
            var player: String
            var points: Int
        }

        @Table("articles")
        struct Article: Equatable, Sendable {
            let id: Int
            var title: String
            var body: String
        }

        static let schema: [ISO_9075.Fragment] = [
            #"""
            CREATE TABLE "samples" (
              "id" BIGSERIAL PRIMARY KEY,
              "count" BIGINT NOT NULL,
              "ratio" DOUBLE PRECISION NOT NULL,
              "isActive" BOOLEAN NOT NULL,
              "name" TEXT NOT NULL,
              "bytes" BYTEA NOT NULL,
              "createdAt" TIMESTAMPTZ NOT NULL,
              "reference" UUID NOT NULL,
              "settings" JSONB NOT NULL,
              "tags" TEXT[] NOT NULL,
              "note" TEXT
            )
            """#,
            #"CREATE TABLE "accounts" ("id" BIGINT PRIMARY KEY, "owner" TEXT NOT NULL, "balance" BIGINT NOT NULL)"#,
            #"CREATE TABLE "scores" ("id" BIGSERIAL PRIMARY KEY, "player" TEXT NOT NULL, "points" BIGINT NOT NULL)"#,
            #"CREATE TABLE "articles" ("id" BIGSERIAL PRIMARY KEY, "title" TEXT NOT NULL, "body" TEXT NOT NULL)"#,
        ]

        static func sample(_ name: String, count: Int = 1) throws -> Sample.Draft {
            Sample.Draft(
                count: count,
                ratio: 0.5,
                isActive: true,
                name: name,
                bytes: [0x00, 0x7F, 0xFF].map(Byte.init(bitPattern:)),
                createdAt: try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 123_456_000),
                reference: try RFC_4122.UUID("0190b8a4-8a4e-7d2e-9f1c-3b2a1d0e4f5a"),
                settings: ["volume": 7],
                tags: ["a", "b,c", #"d"e"#],
                note: nil
            )
        }
    }
#endif
