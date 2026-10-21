#if PostgresNIO
    import ISO_9075_Call_Level_Interface
    import ISO_9075_Foundation
    import PostgreSQL
    import PostgreSQL_Test_Support
    import SQL
    import Testing

    @Suite(.serialized, .postgreSQL(configuration: .test, setUp: LiveFixtures.schema))
    struct `Live notifications` {
        typealias Account = LiveFixtures.Account

        var database: PostgreSQL.Database { PostgreSQL.TestDatabase.database }

        @Test func `a typed stream receives a notification`() async throws {
            let channel = PostgreSQL.Notification.Channel("greetings")
            let database = database
            let received = try await database.listen(on: channel) { stream throws(ISO_9075.Error) in
                try await database.write { connection throws(ISO_9075.Error) in
                    try channel.notify("hello").execute(connection)
                }
                var iterator = stream.makeAsyncIterator()
                return try await iterator.next()
            }
            #expect(received == "hello")
        }

        @Test func `a trigger notifies each change with its rows`() async throws {
            let channel = PostgreSQL.Notification.Channel<PostgreSQL.Notification.Change<Account>>(changes: "account_changes")
            let database = database
            try await database.write { connection throws(ISO_9075.Error) in
                for statement in channel.setUp(on: Account.self, includingOld: true) {
                    try statement.execute(connection)
                }
            }
            let changes = try await database.listen(on: channel) { stream throws(ISO_9075.Error) in
                try await database.write { connection throws(ISO_9075.Error) in
                    try Account.insert { Account(id: 1, owner: "ada", balance: 1) }.execute(connection)
                    try Account.where { $0.id.eq(1) }.update { $0.balance = 2 }.execute(connection)
                    try Account.where { $0.id.eq(1) }.delete().execute(connection)
                }
                var iterator = stream.makeAsyncIterator()
                var changes: [PostgreSQL.Notification.Change<Account>] = []
                while changes.count < 3, let change = try await iterator.next() {
                    changes.append(change)
                }
                return changes
            }
            #expect(
                changes == [
                    PostgreSQL.Notification.Change(operation: .insert, new: Account(id: 1, owner: "ada", balance: 1), old: nil),
                    PostgreSQL.Notification.Change(
                        operation: .update,
                        new: Account(id: 1, owner: "ada", balance: 2),
                        old: Account(id: 1, owner: "ada", balance: 1)
                    ),
                    PostgreSQL.Notification.Change(operation: .delete, new: nil, old: Account(id: 1, owner: "ada", balance: 2)),
                ]
            )
            try await database.write { connection throws(ISO_9075.Error) in
                for statement in channel.tearDown(on: Account.self) {
                    try statement.execute(connection)
                }
            }
        }

        @Test func `a client notify of a change decodes like a trigger`() async throws {
            let channel = PostgreSQL.Notification.Channel<PostgreSQL.Notification.Change<Account>>(changes: "manual_changes")
            let database = database
            let change = PostgreSQL.Notification.Change(operation: .insert, new: Account(id: 9, owner: "zed", balance: 4), old: nil)
            let received = try await database.listen(on: channel) { stream throws(ISO_9075.Error) in
                try await database.write { connection throws(ISO_9075.Error) in
                    try channel.notify(change).execute(connection)
                }
                var iterator = stream.makeAsyncIterator()
                return try await iterator.next()
            }
            #expect(received == change)
        }
    }
#endif
