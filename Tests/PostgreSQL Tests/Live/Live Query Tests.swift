#if PostgresNIO && !os(Windows)
    import Byte
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import SQL
    import Testing

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema + LiveQueryFixtures.seed))
    struct `Live queries` {
        typealias Score = LiveFixtures.Score
        typealias Article = LiveFixtures.Article
        typealias Sample = LiveFixtures.Sample

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `window functions rank within partitions`() async throws {
            let ranks = try await database.read { connection throws(ISO_9075.Error) in
                try Score
                    .select { ($0.player, $0.points, PostgreSQL.Window.rank().over { $0.partition(by: Score.columns.player).order(by: Score.columns.points.desc()) }) }
                    .order { $0.player }
                    .order { $0.points.desc() }
                    .fetch.all(connection)
            }
            #expect(ranks.map(\.2) == [1, 2, 3, 1, 2])
        }

        @Test func `a named window is shared by functions`() async throws {
            let rows = try await database.read { connection throws(ISO_9075.Error) in
                try Score
                    .select { ($0.points, PostgreSQL.Window.rowNumber().over("by_points")) }
                    .window("by_points") { $0.order(by: Score.columns.points) }
                    .order(by: \.points)
                    .fetch.all(connection)
            }
            #expect(rows.map(\.1) == [1, 2, 3, 4, 5])
        }

        @Test func `a running sum uses a frame`() async throws {
            let sums = try await database.read { connection throws(ISO_9075.Error) in
                try Score
                    .select { PostgreSQL.Window.Function(aggregate: $0.points.sum()).over { $0.order(by: Score.columns.points).rows(between: .unboundedPreceding, and: .currentRow) } }
                    .order(by: \.points)
                    .fetch.all(connection)
            }
            #expect(sums == [10, 30, 60, 100, 150])
        }

        @Test func `aggregates group and round`() async throws {
            let (agg, deviation, rounded) = try await database.read { connection throws(ISO_9075.Error) in
                (
                    try Score.group(by: \.player).select { ($0.player, $0.points.arrayAgg(order: $0.points.asc()), $0.points.stringAgg("-", order: $0.points.asc())) }
                        .order(by: \.player)
                        .fetch.all(connection),
                    try Score.select { $0.points.stddev() }.fetch.one(connection),
                    try Score.where { $0.points.eq(10) }.select { ($0.points.cast() / 3.0).round(2) }.fetch.one(connection)
                )
            }
            #expect(agg.map(\.0) == ["ada", "bob"])
            #expect(agg.map(\.1) == [[20, 30, 50], [10, 40]])
            #expect(agg.map(\.2) == ["20-30-50", "10-40"])
            #expect(abs(((deviation ?? nil) ?? 0) - 15.811) < 0.001)
            #expect(rounded == 3.33)
        }

        @Test func `full-text search matches and ranks`() async throws {
            let titles = try await database.read { connection throws(ISO_9075.Error) in
                try Article
                    .where { $0.body.matches(PostgreSQL.TextSearch.query("swift databases", configuration: .english), configuration: .english) }
                    .select { ($0.title, PostgreSQL.TextSearch.vector($0.body, configuration: .english).rank(PostgreSQL.TextSearch.query("swift", configuration: .english))) }
                    .order(by: \.title)
                    .fetch.all(connection)
            }
            #expect(titles.map(\.0) == ["Swift and databases"])
            #expect(titles.allSatisfy { $0.1 > 0 })
        }

        @Test func `JSONB operators read and edit documents`() async throws {
            let draft = try LiveFixtures.sample("json")
            let (volume, hasVolume, contained, edited) = try await database.write { connection throws(ISO_9075.Error) in
                try Sample.insert { draft }.execute(connection)
                let sample = Sample.where { $0.name.eq("json") }
                return (
                    try sample.select { $0.settings.fieldAsText("volume") }.fetch.one(connection),
                    try sample.select { $0.settings.hasKey("volume") }.fetch.one(connection),
                    try sample.select { $0.settings.contains(["volume": 7]) }.fetch.one(connection),
                    try sample.select { $0.settings.concat(["bass": 2]).removing("volume") }.fetch.one(connection)
                )
            }
            #expect(volume == "7")
            #expect(hasVolume == true)
            #expect(contained == true)
            #expect(edited == ["bass": 2])
        }
    }

    enum LiveQueryFixtures {
        static let seed: [ISO_9075.Fragment] = [
            #"INSERT INTO "scores" ("player", "points") VALUES ('bob', 10), ('ada', 20), ('ada', 30), ('bob', 40), ('ada', 50)"#,
            #"""
            INSERT INTO "articles" ("title", "body") VALUES
              ('Swift and databases', 'Swift talks to databases through typed queries'),
              ('Gardening', 'Tomatoes need sun and water')
            """#,
        ]
    }
#endif
