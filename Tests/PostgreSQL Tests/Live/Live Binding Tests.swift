#if PostgresNIO
    import Byte
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import RFC_4122
    import SQL
    import Testing
    import Time

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema))
    struct `Live bindings` {
        typealias Sample = LiveFixtures.Sample

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `every binding type round-trips through a row`() async throws {
            let draft = try LiveFixtures.sample("round trip")
            let inserted = try await database.write { connection throws(ISO_9075.Error) in
                try Sample.insert { draft }.returning(\.self).fetchOne(connection)
            }
            let fetched = try await database.read { connection throws(ISO_9075.Error) in
                try Sample.where { $0.name.eq("round trip") }.fetchOne(connection)
            }
            #expect(inserted == fetched)
            #expect(fetched?.count == draft.count)
            #expect(fetched?.ratio == draft.ratio)
            #expect(fetched?.isActive == draft.isActive)
            #expect(fetched?.bytes == draft.bytes)
            #expect(fetched?.createdAt == draft.createdAt)
            #expect(fetched?.reference == draft.reference)
            #expect(fetched?.settings == draft.settings)
            #expect(fetched?.tags == draft.tags)
            #expect(fetched?.note == nil)
        }

        @Test func `a connection answers a bound select`() async throws {
            let values = try await database.read { connection throws(ISO_9075.Error) in
                try connection.fetchAll("SELECT \(ISO_9075.Value.int(41)) + 1, \(ISO_9075.Value.text("ok"))") { row throws(ISO_9075.Error) in
                    [try row.value(at: 0), try row.value(at: 1)]
                }
            }
            #expect(values == [[.int(42), .text("ok")]])
        }

        @Test func `an instant binds as TIMESTAMPTZ independent of the session time zone`() async throws {
            let instant = Time.Instant(secondsSinceUnixEpoch: 1_767_225_600)
            let epoch = try await database.read { connection throws(ISO_9075.Error) in
                _ = try connection.execute("SET LOCAL TIME ZONE 'America/New_York'")
                return try connection.fetchAll(
                    "SELECT CAST(extract(epoch FROM \(ISO_9075.Value.timestamp(instant))) AS BIGINT)"
                ) { row throws(ISO_9075.Error) in try row.value(at: 0) }
            }
            #expect(epoch == [.int(1_767_225_600)])
        }

        @Test func `an inlined instant and bytes keep their meaning`() async throws {
            let instant = Time.Instant(secondsSinceUnixEpoch: 1_767_225_600)
            let bytes = [0x01, 0xAB].map(Byte.init(bitPattern:))
            let sql = try PostgreSQL().inline(
                "SELECT CAST(extract(epoch FROM \(ISO_9075.Value.timestamp(instant))) AS BIGINT), \(ISO_9075.Value.blob(bytes))"
            )
            let values = try await database.read { connection throws(ISO_9075.Error) in
                try connection.fetchAll("\(raw: sql)") { row throws(ISO_9075.Error) in [try row.value(at: 0), try row.value(at: 1)] }
            }
            #expect(values == [[.int(1_767_225_600), .blob(bytes)]])
        }

        @Test func `an instant round-trips as TIMESTAMPTZ to the microsecond`() async throws {
            let instants = [
                try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 123_456_789),
                try Time.Instant(secondsSinceUnixEpoch: 946_684_800, nanosecondFraction: 999),
                try Time.Instant(secondsSinceUnixEpoch: -1, nanosecondFraction: 999_999_999),
            ]
            let fetched = try await database.read { connection throws(ISO_9075.Error) in
                try instants.map { instant throws(ISO_9075.Error) in
                    try connection.fetchAll("SELECT \(ISO_9075.Value.timestamp(instant)), pg_typeof(\(ISO_9075.Value.timestamp(instant)))::TEXT") { row throws(ISO_9075.Error) in
                        [try row.value(at: 0), try row.value(at: 1)]
                    }
                }
            }
            #expect(
                fetched == [
                    [[.timestamp(try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 123_456_000)), .text("timestamp with time zone")]],
                    [[.timestamp(Time.Instant(secondsSinceUnixEpoch: 946_684_800)), .text("timestamp with time zone")]],
                    [[.timestamp(try Time.Instant(secondsSinceUnixEpoch: -1, nanosecondFraction: 999_999_000)), .text("timestamp with time zone")]],
                ]
            )
        }

        @Test func `an instant keeps its microseconds through a row`() async throws {
            var draft = try LiveFixtures.sample("microseconds")
            draft.createdAt = try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 654_321_987)
            let fetched = try await database.write { [draft] connection throws(ISO_9075.Error) in
                try Sample.insert { draft }.returning(\.createdAt).fetchOne(connection)
            }
            #expect(fetched == (try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 654_321_000)))
        }

        @Test func `an empty array binds with its element's array type`() async throws {
            let kinds: [(ISO_9075.Value.Kind, String)] = [
                (.bool, "boolean[]"),
                (.int, "bigint[]"),
                (.double, "double precision[]"),
                (.text, "text[]"),
                (.blob, "bytea[]"),
                (.timestamp, "timestamp with time zone[]"),
                (.uuid, "uuid[]"),
            ]
            let types = try await database.read { connection throws(ISO_9075.Error) in
                try kinds.map { kind, _ throws(ISO_9075.Error) in
                    try connection.fetchAll(
                        "SELECT pg_typeof(\(ISO_9075.Value.array([], of: kind)))::TEXT, cardinality(\(ISO_9075.Value.array([], of: kind)))"
                    ) { row throws(ISO_9075.Error) in [try row.value(at: 0), try row.value(at: 1)] }
                }
            }
            #expect(types == kinds.map { _, type in [[.text(type), .int(0)]] })
        }

        @Test func `an empty array round-trips through a typed column`() async throws {
            var draft = try LiveFixtures.sample("empty tags")
            draft.tags = []
            let fetched = try await database.write { [draft] connection throws(ISO_9075.Error) in
                try Sample.insert { draft }.returning(\.tags).fetchOne(connection)
            }
            #expect(fetched == [])
        }

        @Test func `a cast uses the PostgreSQL type names`() async throws {
            let draft = try LiveFixtures.sample("cast", count: 7)
            let texts = try await database.write { connection throws(ISO_9075.Error) in
                try Sample.insert { draft }.execute(connection)
                return try Sample.where { $0.name.eq("cast") }.select { ($0.count.cast(as: String.self), $0.count.cast()) }.fetchAll(connection)
            }
            #expect(texts.map(\.0) == ["7"])
            #expect(texts.map(\.1) == [7.0])
        }
    }
#endif
