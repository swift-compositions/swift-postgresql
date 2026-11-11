#if PostgresNIO
    import ISO_9075_Call_Level_Interface
    import PostgreSQL
    import PostgreSQL_Test_Support
    import SQL_Test_Support
    import Testing

    @Suite(.postgreSQL(configuration: .test, setUp: []))
    struct `Live execution laws` {
        @Test func `swift-sql's statements run on PostgreSQL as the laws expect`() async throws {
            #expect(try await Laws.violations(of: PostgreSQL.TestDatabase.database) == [])
        }
    }
#endif
