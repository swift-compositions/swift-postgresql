#if PostgresNIO && !os(Windows)
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import SQL_Migrations
    import Synchronization
    import Testing

    /// What a website does to its database that the other suites don't: many callers at once, more work than
    /// connections, callers that give up, and connections that die under them (#27).
    @Suite(
        .serialized,
        .postgreSQL(configuration: .test, setUp: [#"CREATE TABLE "writes" ("writer" BIGINT PRIMARY KEY)"#])
    )
    struct `Live load` {
        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        /// A database of its own on the suite's database, with `poolSize` connections.
        func pool(_ poolSize: Int, acquireTimeout: Duration = .seconds(30)) throws -> PostgreSQL.Database {
            var configuration = database.configuration
            configuration.poolSize = poolSize
            configuration.acquireTimeout = acquireTimeout
            return try PostgreSQL.Database(configuration: configuration)
        }

        static func int(_ connection: PostgreSQL.Connection, _ query: ISO_9075.Fragment) throws -> Int64? {
            let values = try connection.fetchAll(query) { row throws(ISO_9075.Error) -> ISO_9075.Value in
                try row.value(at: 0)
            }
            guard case .int(let value)? = values.first else { return nil }
            return value
        }

        static func waitUntil(_ condition: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(20)
            while !condition() {
                guard ContinuousClock.now < deadline else { throw PostgreSQL.Error(kind: .timeout, message: "waited") }
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test func `200 concurrent reads and writes over 10 connections all finish, every write stored once`() async throws {
            _ = try await database.execute(#"DELETE FROM "writes""#)
            let pool = try pool(10)
            let busy = Atomic<Int>(0)
            let peak = Atomic<Int>(0)
            try await withThrowingTaskGroup { group in
                (0..<200).forEach { writer in
                    group.addTask {
                        let measure: @Sendable () -> Void = {
                            let now = busy.add(1, ordering: .relaxed).newValue
                            peak.max(now, ordering: .relaxed)
                        }
                        if writer.isMultiple(of: 2) {
                            try await pool.write { connection in
                                measure()
                                defer { busy.subtract(1, ordering: .relaxed) }
                                _ = try connection.execute(
                                    #"INSERT INTO "writes" ("writer") VALUES (\#(ISO_9075.Value.int(Int64(writer))))"#
                                )
                                _ = try connection.execute("SELECT pg_sleep(0.01)")
                            }
                        } else {
                            _ = try await pool.read { connection in
                                measure()
                                defer { busy.subtract(1, ordering: .relaxed) }
                                return try Self.int(connection, #"SELECT count(*) FROM "writes""#)
                            }
                        }
                    }
                }
                try await group.waitForAll()
            }
            let writers = try await database.read { connection in
                try connection.fetchAll(#"SELECT "writer" FROM "writes" ORDER BY "writer""#) {
                    row throws(ISO_9075.Error) -> ISO_9075.Value in try row.value(at: 0)
                }
            }
            #expect(writers == stride(from: 0, to: 200, by: 2).map { ISO_9075.Value.int(Int64($0)) })
            #expect(peak.load(ordering: .relaxed) <= 10, "never more bodies at once than connections")
            #expect(peak.load(ordering: .relaxed) > 1, "bodies ran concurrently")
            await pool.close()
        }

        @Test func `more work than connections waits, and gives up after the acquire timeout with an owned error`() async throws {
            let pool = try pool(1, acquireTimeout: .milliseconds(500))
            let holding = Atomic<Bool>(false)
            let holder = Task {
                try await pool.read { connection in
                    holding.store(true, ordering: .releasing)
                    _ = try connection.execute("SELECT pg_sleep(2)")
                }
            }
            try await Self.waitUntil { holding.load(ordering: .acquiring) }
            let start = ContinuousClock.now
            let error = await #expect(throws: PostgreSQL.Error.self) {
                try await pool.read { connection in _ = try connection.execute("SELECT 1") }
            }
            let waited = ContinuousClock.now - start
            #expect(error?.kind == .timeout)
            #expect(waited >= .milliseconds(450))
            #expect(waited < .milliseconds(1800), "it gave up before the connection came free")
            try await holder.value

            let queued = Atomic<Bool>(false)
            let second = Task {
                try await pool.read { connection in
                    queued.store(true, ordering: .releasing)
                    _ = try connection.execute("SELECT pg_sleep(0.2)")
                }
            }
            try await Self.waitUntil { queued.load(ordering: .acquiring) }
            try await pool.read { connection in _ = try connection.execute("SELECT 1") }
            try await second.value
            await pool.close()
        }

        @Test func `a task cancelled while it holds a connection gives it back clean`() async throws {
            let pool = try pool(1)
            let backend = Atomic<Int64>(0)
            let task = Task {
                try await pool.write { connection in
                    _ = try connection.execute(#"INSERT INTO "writes" ("writer") VALUES (-1)"#)
                    backend.store(try Self.int(connection, "SELECT pg_backend_pid()") ?? -1, ordering: .releasing)
                    _ = try connection.execute("SELECT pg_sleep(0.5)")
                }
            }
            try await Self.waitUntil { backend.load(ordering: .acquiring) != 0 }
            task.cancel()
            let error = await #expect(throws: PostgreSQL.Error.self) { try await task.value }
            #expect(error?.kind == .cancelled)

            let (pid, transaction, kept) = try await pool.writeWithoutTransaction { connection in
                (
                    try Self.int(connection, "SELECT pg_backend_pid()"),
                    try Self.int(connection, "SELECT CASE WHEN pg_current_xact_id_if_assigned() IS NULL THEN 0 ELSE 1 END"),
                    try Self.int(connection, #"SELECT count(*) FROM "writes" WHERE "writer" = -1"#)
                )
            }
            #expect(pid == backend.load(ordering: .acquiring), "the next caller has the same connection")
            #expect(transaction == 0, "no transaction is open on it")
            #expect(kept == 0, "the cancelled write was rolled back")
            await pool.close()
        }

        @Test func `a connection killed mid-call fails that call with an owned error, and the next call succeeds`() async throws {
            let pool = try pool(2)
            let backend = Atomic<Int64>(0)
            let victim = Task {
                try await pool.write { connection in
                    backend.store(try Self.int(connection, "SELECT pg_backend_pid()") ?? -1, ordering: .releasing)
                    _ = try connection.execute("SELECT pg_sleep(10)")
                }
            }
            try await Self.waitUntil { backend.load(ordering: .acquiring) != 0 }
            let killed = backend.load(ordering: .acquiring)
            _ = try await database.execute("SELECT pg_terminate_backend(CAST(\(ISO_9075.Value.int(killed)) AS INTEGER))")
            let start = ContinuousClock.now
            let error = await #expect(throws: PostgreSQL.Error.self) { try await victim.value }
            #expect(error?.kind == .closed)
            #expect(ContinuousClock.now - start < .seconds(5), "the call failed when its connection died, not after its sleep")

            let next = try await pool.read { connection in try Self.int(connection, "SELECT pg_backend_pid()") }
            #expect(next != nil && next != killed, "the next call runs on a new connection")
            await pool.close()
        }

        @Test func `the migrator runs from empty, and a second run applies nothing`() async throws {
            let runs = Atomic<Int>(0)
            var migrator = Migrator<PostgreSQL.Database>()
            migrator.register("Create makers") { connection throws(ISO_9075.Error) in
                runs.add(1, ordering: .relaxed)
                _ = try connection.execute(#"CREATE TABLE "makers" ("id" BIGINT PRIMARY KEY, "name" TEXT NOT NULL)"#)
            }
            migrator.register("Index makers by name") { connection throws(ISO_9075.Error) in
                runs.add(1, ordering: .relaxed)
                _ = try connection.execute(#"CREATE INDEX "makers_name" ON "makers" ("name")"#)
            }
            try await migrator.migrate(database)
            #expect(runs.load(ordering: .relaxed) == 2)
            try await migrator.migrate(database)
            #expect(runs.load(ordering: .relaxed) == 2, "the second run applied nothing")
            let recorded = try await database.read { connection in
                try Self.int(connection, #"SELECT count(*) FROM "_sql_migrations""#)
            }
            #expect(recorded == 2)
        }
    }
#endif
