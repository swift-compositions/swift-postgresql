#if PostgresNIO && !os(Windows)
    import Foundation
    import ISO_9075_Call_Level_Interface
    import PostgreSQL
    import PostgreSQL_Test_Support
    import Testing

    /// Neither Sendable nor a value: what a body may capture and what it may return.
    private final class Tally {
        var count = 0
    }

    private func thread() -> ObjectIdentifier { ObjectIdentifier(Thread.current) }

    private struct Refused: Swift.Error, Equatable {}

    /// The rows with an id in `ids`: each test counts its own rows, since the tests of the suite share the table.
    private func counted(
        _ connection: borrowing PostgreSQL.Connection,
        _ ids: ClosedRange<Int64>
    ) throws(ISO.`9075`.Error) -> ISO.`9075`.Value? {
        try connection.fetchOne(
            #"SELECT COUNT(*) FROM "lent_items" WHERE "id" BETWEEN \#(.int(ids.lowerBound)) AND \#(.int(ids.upperBound))"#
        ) { row throws(ISO.`9075`.Error) in try row.value(at: 0) }
    }

    @Suite(.postgreSQL(configuration: .test, setUp: [#"CREATE TABLE "lent_items" ("id" INTEGER PRIMARY KEY)"#]))
    struct `Live Lent Connection Tests` {
        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `a body captures what is not Sendable and returns what is not Sendable`() async throws {
            let captured = Tally()
            let returned: Tally = try await database.write { connection throws(ISO.`9075`.Error) in
                captured.count += 1
                let result = Tally()
                result.count = try connection.execute(#"INSERT INTO "lent_items" ("id") VALUES (1)"#)
                return result
            }
            returned.count += 100
            #expect(returned.count == 101)
        }

        @Test @MainActor func `a body runs off the caller's thread and the caller is back on its actor after it`() async throws {
            let caller = thread()
            let body = try await database.read { _ throws(ISO.`9075`.Error) in thread() }
            MainActor.assertIsolated()
            #expect(body != caller)
        }

        @Test func `a body's own error comes back as the body's, and the write is rolled back`() async throws {
            await #expect(throws: ISO.`9075`.Failure<Refused>.body(Refused())) {
                try await database.write { connection throws(Refused) in
                    do throws(ISO.`9075`.Error) {
                        _ = try connection.execute(#"INSERT INTO "lent_items" ("id") VALUES (2)"#)
                    } catch {
                        Issue.record(error)
                    }
                    throw Refused()
                }
            }
            let count = try await database.read { connection throws(ISO.`9075`.Error) in try counted(connection, 2...2) }
            #expect(count == .int(0))
        }

        @Test func `a task cancelled while its body runs keeps its connection until the body is over, and rolls back`() async throws {
            let database = database
            let (entered, signal) = AsyncStream<Void>.makeStream()
            let release = DispatchSemaphore(value: 0)
            let task = Task {
                try await database.write { connection throws(ISO.`9075`.Error) in
                    _ = try connection.execute(#"INSERT INTO "lent_items" ("id") VALUES (3)"#)
                    signal.yield()
                    release.wait()
                    // The task is cancelled by now. The connection is still this body's: the statement runs.
                    return try counted(connection, 3...3)
                }
            }
            for await _ in entered { break }
            task.cancel()
            release.signal()
            let outcome = await task.result
            let error = #expect(throws: ISO.`9075`.Error.self) { try outcome.get() }
            #expect(error.map { "\($0)" }?.contains("cancelled") == true)
            let count = try await database.read { connection throws(ISO.`9075`.Error) in try counted(connection, 3...3) }
            #expect(count == .int(0))
        }

        @Test func `more writes at once than the pool has connections all commit`() async throws {
            let database = database
            try await withThrowingTaskGroup(of: Void.self) { group in
                for index in 100..<140 {
                    group.addTask {
                        _ = try await database.write { connection throws(ISO.`9075`.Error) in
                            try connection.execute(#"INSERT INTO "lent_items" ("id") VALUES (\#(.int(Int64(index))))"#)
                        }
                    }
                }
                try await group.waitForAll()
            }
            let count = try await database.read { connection throws(ISO.`9075`.Error) in try counted(connection, 100...139) }
            #expect(count == .int(40))
        }
    }
#endif
