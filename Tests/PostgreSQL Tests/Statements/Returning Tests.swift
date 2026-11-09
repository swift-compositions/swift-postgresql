import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Returning` {
    @Test func `an insert returns the chosen columns`() throws {
        let rendering = try PostgreSQL().render(
            ReturningFixtures.Note.insert { ReturningFixtures.Note.Draft(body: "hi") }.returning { ($0.id, $0.body) }.query
        )
        #expect(rendering.sql.hasSuffix(#"RETURNING "id", "body""#))
    }

    @Test func `an update returns the whole row`() throws {
        let rendering = try PostgreSQL().render(
            ReturningFixtures.Note.update { $0.body = "edited" }.returning(\.self).query
        )
        #expect(rendering.sql.hasSuffix(#"RETURNING "id", "body""#))
    }

    @Test func `a delete returns one column`() throws {
        let rendering = try PostgreSQL().render(
            ReturningFixtures.Note.where { $0.id.eq(1) }.delete().returning { $0.id }.query
        )
        #expect(rendering.sql.hasSuffix(#"RETURNING "id""#))
    }
}
