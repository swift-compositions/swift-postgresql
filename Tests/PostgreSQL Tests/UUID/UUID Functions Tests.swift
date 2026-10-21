import ISO_9075_Foundation
import PostgreSQL
import RFC_4122
import SQL
import SQL_Macros
import Testing
import Time

@Suite struct `UUID functions` {
    @Test func `generation functions`() {
        #expect(PostgreSQL().render(PostgreSQL.UUID.random().queryFragment).sql == "gen_random_uuid()")
        #expect(PostgreSQL().render(PostgreSQL.UUID.v4().queryFragment).sql == "uuidv4()")
        #expect(PostgreSQL().render(PostgreSQL.UUID.v7().queryFragment).sql == "uuidv7()")
    }

    @Test func `v7 inlines the shift as an escaped interval literal`() {
        #expect(
            PostgreSQL().render(PostgreSQL.UUID.v7(shift: "-1 hour").queryFragment)
                == ISO_9075.Rendering(
                    sql: "uuidv7('-1 hour'::interval)",
                    values: []
                )
        )
        #expect(PostgreSQL().render(PostgreSQL.UUID.v7(shift: "1' day").queryFragment).sql == "uuidv7('1'' day'::interval)")
    }

    @Test func `extraction from a UUID column`() {
        let version: some QueryExpression<Int?> = UUIDFixtures.User.columns.id.extractVersion()
        let timestamp: some QueryExpression<Time.Instant?> = UUIDFixtures.User.columns.id.extractTimestamp()
        #expect(PostgreSQL().render(version.queryFragment).sql == #"uuid_extract_version("users"."id")"#)
        #expect(PostgreSQL().render(timestamp.queryFragment).sql == #"uuid_extract_timestamp("users"."id")"#)
    }

    @Test func `extraction from an optional UUID column`() {
        #expect(PostgreSQL().render(UUIDFixtures.User.columns.referrerID.extractVersion().queryFragment).sql == #"uuid_extract_version("users"."referrerID")"#)
    }

    @Test func `generation inside a select`() {
        let sql = PostgreSQL().render(UUIDFixtures.User.select { _ in PostgreSQL.UUID.v7() }.query).sql
        #expect(sql.hasPrefix("SELECT uuidv7()"))
    }
}
