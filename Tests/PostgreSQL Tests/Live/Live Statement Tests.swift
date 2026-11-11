#if PostgresNIO && !os(Windows)
    import Cardinal
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import SQL
    import Testing

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema))
    struct `Live statements` {
        typealias Account = LiveFixtures.Account

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `insert, update and delete return their rows`() async throws {
            let (inserted, updated, deleted, remaining) = try await database.write { connection throws(ISO_9075.Error) in
                let inserted = try Account.insert { Account(id: 1, owner: "ada", balance: 10) }.returning(\.self).fetch.all(connection)
                let updated = try Account.where { $0.id.eq(1) }.update { $0.balance += 5 }.returning { $0.balance }.fetch.all(connection)
                let deleted = try Account.where { $0.id.eq(1) }.delete().returning { $0.owner }.fetch.all(connection)
                return (inserted, updated, deleted, try Account.fetch.count(connection))
            }
            #expect(inserted == [Account(id: 1, owner: "ada", balance: 10)])
            #expect(updated == [15])
            #expect(deleted == ["ada"])
            #expect(remaining == 0)
        }

        @Test func `a trigger function whose body contains $function$ is created as written`() async throws {
            let body = "BEGIN RAISE NOTICE '$function$'; RETURN NEW; END;"
            let source = try await database.write { connection throws(ISO_9075.Error) in
                try PostgreSQL.Function("quoted").create(body: body).execute(connection)
                return try connection.fetchAll("SELECT prosrc FROM pg_proc WHERE proname = 'quoted'") {
                    row throws(ISO_9075.Error) -> ISO_9075.Value in try row.value(at: 0)
                }
            }
            #expect(source == [.text("\n\(body)\n")])
        }

        @Test func `an upsert updates the conflicting row`() async throws {
            let accounts = try await database.write { connection throws(ISO_9075.Error) in
                try Account.insert { Account(id: 2, owner: "bob", balance: 1) }.execute(connection)
                try Account.upsert { Account(id: 2, owner: "bob", balance: 99) }.execute(connection)
                try Account.upsert { Account(id: 3, owner: "cy", balance: 3) }.execute(connection)
                return try Account.order(by: \.id).fetch.all(connection)
            }
            #expect(accounts == [Account(id: 2, owner: "bob", balance: 99), Account(id: 3, owner: "cy", balance: 3)])
            _ = try await database.execute(#"DELETE FROM "accounts""#)
        }
    }

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema))
    struct `Live transactions` {
        typealias Account = LiveFixtures.Account

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        func count() async throws -> Cardinal {
            try await database.read { connection throws(ISO_9075.Error) in try Account.fetch.count(connection) }
        }

        @Test func `withRollback discards its writes`() async throws {
            let inside = try await database.withRollback { connection throws(ISO_9075.Error) in
                try Account.insert { Account(id: 10, owner: "tmp", balance: 0) }.execute(connection)
                return try Account.fetch.count(connection)
            }
            #expect(inside == 1)
            #expect(try await count() == 0)
        }

        @Test func `a failing write rolls back`() async throws {
            await #expect(throws: ISO_9075.Error.self) {
                try await database.write { connection throws(ISO_9075.Error) in
                    try Account.insert { Account(id: 11, owner: "a", balance: 0) }.execute(connection)
                    try Account.insert { Account(id: 11, owner: "duplicate", balance: 0) }.execute(connection)
                }
            }
            #expect(try await count() == 0)
        }

        @Test func `a failed savepoint keeps the outer transaction`() async throws {
            let owners = try await database.withRollback { connection throws(ISO_9075.Error) in
                try Account.insert { Account(id: 12, owner: "kept", balance: 0) }.execute(connection)
                do {
                    try connection.withSavepoint { connection throws(ISO_9075.Error) in
                        try Account.insert { Account(id: 13, owner: "undone", balance: 0) }.execute(connection)
                        try Account.insert { Account(id: 13, owner: "duplicate", balance: 0) }.execute(connection)
                    }
                } catch {}
                try connection.withSavepoint("named") { connection throws(ISO_9075.Error) in
                    try Account.insert { Account(id: 14, owner: "released", balance: 0) }.execute(connection)
                }
                return try Account.order(by: \.id).select(\.owner).fetch.all(connection)
            }
            #expect(owners == ["kept", "released"])
        }

        @Test func `a serializable write commits`() async throws {
            try await database.write(isolation: .serializable) { connection throws(ISO_9075.Error) in
                try Account.insert { Account(id: 15, owner: "serial", balance: 0) }.execute(connection)
            }
            #expect(try await count() == 1)
            _ = try await database.execute(#"DELETE FROM "accounts""#)
        }
    }

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema))
    struct `Live cursors` {
        typealias Score = LiveFixtures.Score

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `a cursor fetches every row in batches`() async throws {
            let (batched, closedEarly) = try await database.write { connection throws(ISO_9075.Error) in
                _ = try connection.execute(#"INSERT INTO "scores" ("player", "points") SELECT 'p' || n, n FROM generate_series(1, 25) AS n"#)
                var cursor = try Score.order(by: \.points).fetchCursor(connection, batch: 10)
                let batched = try cursor.fetchAll().map(\.points)
                var partial = try Score.order(by: \.points).select(\.points).fetchCursor(connection, batch: 4)
                let first = try partial.next()
                try partial.close()
                return (batched, first)
            }
            #expect(batched == Array(1...25))
            #expect(closedEarly == 1)
        }
    }
#endif
