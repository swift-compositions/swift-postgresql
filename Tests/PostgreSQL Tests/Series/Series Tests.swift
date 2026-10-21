import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing
import Time

@Suite struct `Set-returning series` {
    @Test func `an integer series binds its bounds`() {
        let rendering = PostgreSQL().render(PostgreSQL.Series.generate(from: 1, through: 10).queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: "generate_series($1, $2)", values: [.int(1), .int(10)]))
    }

    @Test func `an integer series binds its step`() {
        let rendering = PostgreSQL().render(PostgreSQL.Series.generate(from: 0, through: 100, by: 10).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: "generate_series($1, $2, $3)",
                    values: [.int(0), .int(100), .int(10)]
                )
        )
    }

    @Test func `a timestamp series inlines its interval`() {
        let event = SeriesFixtures.Event.columns
        let rendering = PostgreSQL().render(
            PostgreSQL.Series.generate(from: event.startsAt, through: event.endsAt, every: "1 day").queryFragment
        )
        #expect(rendering.sql == #"generate_series("events"."startsAt", "events"."endsAt", '1 day'::interval)"#)
    }

    @Test func `array subscripts render their dimension`() {
        let tags = SeriesFixtures.Post.columns.tags
        #expect(
            PostgreSQL().render(PostgreSQL.Series.subscripts(of: tags).queryFragment).sql
                == #"generate_subscripts("posts"."tags", 1)"#
        )
        #expect(
            PostgreSQL().render(PostgreSQL.Series.subscripts(of: tags, dimension: 1, reversed: true).queryFragment).sql
                == #"generate_subscripts("posts"."tags", 1, TRUE)"#
        )
    }
}

@Suite struct `Set-returning regular expressions` {
    let title = SeriesFixtures.Post.columns.title

    @Test func `regexp_matches binds its pattern and flags`() {
        let rendering = PostgreSQL().render(title.regexpMatches("a+").queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"regexp_matches("posts"."title", $1, $2)"#,
                    values: [.text("a+"), .text("g")]
                )
        )
    }

    @Test func `regexp_split_to_table binds flags only when given`() {
        #expect(
            PostgreSQL().render(title.regexpSplitToTable(",").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"regexp_split_to_table("posts"."title", $1)"#,
                    values: [.text(",")]
                )
        )
        #expect(
            PostgreSQL().render(title.regexpSplitToTable(",", flags: "i").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"regexp_split_to_table("posts"."title", $1, $2)"#,
                    values: [.text(","), .text("i")]
                )
        )
    }
}
