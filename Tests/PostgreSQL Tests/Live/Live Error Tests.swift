#if PostgresNIO && !os(Windows)
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import Testing

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: [#"CREATE TABLE "keys" ("key" TEXT PRIMARY KEY)"#]))
    struct `Live errors` {
        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        struct Refusal: Error, Equatable {}

        @Test func `a unique violation reaches the caller with SQLSTATE 23505`() async throws {
            _ = try await database.execute(#"INSERT INTO "keys" VALUES ('taken')"#)
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await database.write { connection in
                    _ = try connection.execute(#"INSERT INTO "keys" VALUES ('new')"#)
                    _ = try connection.execute(#"INSERT INTO "keys" VALUES ('taken')"#)
                }
            }
            #expect(error?.kind == .server)
            #expect(error?.code == .uniqueViolation)
            #expect(error?.code?.rawValue == "23505")
            #expect(error?.code?.class == "23")
            #expect(error?.detail?.contains("taken") == true)
            #expect(error?.statement == #"INSERT INTO "keys" VALUES ('taken')"#)
            let keys = try await database.read { connection in
                try connection.fetchAll(#"SELECT "key" FROM "keys" ORDER BY "key""#) { row throws(ISO_9075.Error) -> ISO_9075.Value in try row.value(at: 0) }
            }
            #expect(keys == [.text("taken")], "the failed write rolled back")
        }

        @Test func `the call-level interface carries the server's SQLSTATE as its diagnostic's state`() async throws {
            _ = try await database.execute(#"INSERT INTO "keys" VALUES ('twice') ON CONFLICT DO NOTHING"#)
            let error = await #expect(throws: ISO_9075.Error.self) {
                try await database.write { connection throws(ISO_9075.Error) in
                    _ = try connection.execute(#"INSERT INTO "keys" VALUES ('twice')"#)
                }
            }
            guard case .diagnostic(let diagnostic)? = error else {
                Issue.record("expected a diagnostic, got \(String(describing: error))")
                return
            }
            #expect(diagnostic.state.rawValue == "23505")
            #expect(diagnostic.state.class == ISO_9075.Diagnostic.State.integrityConstraintViolation.class)
        }

        @Test func `an error of the caller's own comes out unchanged`() async throws {
            await #expect(throws: Refusal()) {
                try await database.write { connection in
                    _ = try connection.execute(#"INSERT INTO "keys" VALUES ('refused')"#)
                    throw Refusal()
                }
            }
            let count = try await database.read { connection in
                try connection.fetchAll(#"SELECT count(*) FROM "keys" WHERE "key" = 'refused'"#) { row throws(ISO_9075.Error) -> ISO_9075.Value in try row.value(at: 0) }
            }
            #expect(count == [.int(0)])
        }

        @Test func `a syntax error has its own code`() async throws {
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await database.read { connection in _ = try connection.execute("SELEC 1") }
            }
            #expect(error?.code == .syntaxError)
        }

        @Test func `a database that does not exist refuses the connection`() async throws {
            var configuration = PostgreSQL.Configuration.test
            configuration.database = "swift_postgresql_no_such_database"
            let missing = try PostgreSQL.Database(configuration: configuration)
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await missing.read { connection in _ = try connection.execute("SELECT 1") }
            }
            #expect(error?.kind == .connect)
            #expect(error?.code == .invalidCatalogName)
            await missing.close()
        }

        @Test(.enabled(if: PostgreSQL.Configuration.test.password != nil, "the server checks passwords only when one is set"))
        func `a wrong password is an authentication error`() async throws {
            var configuration = PostgreSQL.Configuration.test
            configuration.password = "not the password"
            let refused = try PostgreSQL.Database(configuration: configuration)
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await refused.read { connection in _ = try connection.execute("SELECT 1") }
            }
            #expect(error?.kind == .authentication)
            #expect(error?.code == .invalidPassword)
            await refused.close()
        }

        @Test func `nothing listening is a connect error`() async throws {
            var configuration = PostgreSQL.Configuration.test
            configuration.host = "127.0.0.1"
            configuration.port = 1
            configuration.tls = .disabled
            configuration.acquireTimeout = .seconds(20)
            let unreachable = try PostgreSQL.Database(configuration: configuration)
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await unreachable.read { connection in _ = try connection.execute("SELECT 1") }
            }
            #expect(error?.kind == .connect)
            await unreachable.close()
        }

        @Test func `a closed database refuses work`() async throws {
            let closing = try PostgreSQL.Database(configuration: .test)
            await closing.close()
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await closing.read { connection in _ = try connection.execute("SELECT 1") }
            }
            #expect(error?.kind == .closed)
        }
    }
#endif
