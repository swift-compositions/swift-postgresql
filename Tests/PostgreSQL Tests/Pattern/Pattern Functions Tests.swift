import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Pattern matching` {
    let title = PatternFixtures.Document.columns.title

    @Test func `ilike binds the pattern`() {
        #expect(
            PostgreSQL().render(title.ilike("a%").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("documents"."title" ILIKE $1)"#,
                    values: [.text("a%")]
                )
        )
    }

    @Test func `ilike binds an escape character`() {
        #expect(
            PostgreSQL().render(title.ilike("50\\%", escape: "\\").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("documents"."title" ILIKE $1 ESCAPE $2)"#,
                    values: [.text("50\\%"), .text("\\")]
                )
        )
    }

    @Test func `similar to and not similar to`() {
        #expect(
            PostgreSQL().render(title.similarTo("%(b|d)%").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("documents"."title" SIMILAR TO $1)"#,
                    values: [.text("%(b|d)%")]
                )
        )
        #expect(PostgreSQL().render(title.notSimilarTo("%(b|d)%").queryFragment).sql == #"("documents"."title" NOT SIMILAR TO $1)"#)
    }

    @Test func `regex operators`() {
        #expect(
            PostgreSQL().render(title.regexMatch("^A").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("documents"."title" ~ $1)"#,
                    values: [.text("^A")]
                )
        )
        #expect(PostgreSQL().render(title.regexMatchCaseInsensitive("^a").queryFragment).sql == #"("documents"."title" ~* $1)"#)
        #expect(PostgreSQL().render(title.regexNotMatch("^A").queryFragment).sql == #"("documents"."title" !~ $1)"#)
        #expect(PostgreSQL().render(title.regexNotMatchCaseInsensitive("^a").queryFragment).sql == #"("documents"."title" !~* $1)"#)
    }

    @Test func `regexp_like with flags`() {
        #expect(
            PostgreSQL().render(title.regexpLike("^a", flags: "i").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"regexp_like("documents"."title", $1, $2)"#,
                    values: [.text("^a"), .text("i")]
                )
        )
    }

    @Test func `regexp_count fills the start before flags`() {
        #expect(PostgreSQL().render(title.regexpCount("a").queryFragment).sql == #"regexp_count("documents"."title", $1)"#)
        #expect(PostgreSQL().render(title.regexpCount("a", start: 3).queryFragment).sql == #"regexp_count("documents"."title", $1, 3)"#)
        #expect(
            PostgreSQL().render(title.regexpCount("a", flags: "i").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"regexp_count("documents"."title", $1, 1, $2)"#,
                    values: [.text("a"), .text("i")]
                )
        )
    }

    @Test func `regexp_instr places flags after the end option`() {
        #expect(PostgreSQL().render(title.regexpInstr("a", flags: "i").queryFragment).sql == #"regexp_instr("documents"."title", $1, 1, 1, 0, $2)"#)
        #expect(PostgreSQL().render(title.regexpInstr("a", occurrence: 2).queryFragment).sql == #"regexp_instr("documents"."title", $1, 1, 2)"#)
    }

    @Test func `regexp_replace uses the flags form without a start`() {
        #expect(PostgreSQL().render(title.regexpReplace("a", "b").queryFragment).sql == #"regexp_replace("documents"."title", $1, $2)"#)
        #expect(
            PostgreSQL().render(title.regexpReplace("a", "b", flags: "g").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"regexp_replace("documents"."title", $1, $2, $3)"#,
                    values: [.text("a"), .text("b"), .text("g")]
                )
        )
    }

    @Test func `regexp_replace keeps global flags with a start`() {
        #expect(PostgreSQL().render(title.regexpReplace("a", "b", start: 2, flags: "g").queryFragment).sql == #"regexp_replace("documents"."title", $1, $2, 2, 0, $3)"#)
        #expect(PostgreSQL().render(title.regexpReplace("a", "b", start: 2, flags: "i").queryFragment).sql == #"regexp_replace("documents"."title", $1, $2, 2, 1, $3)"#)
        #expect(PostgreSQL().render(title.regexpReplace("a", "b", start: 2).queryFragment).sql == #"regexp_replace("documents"."title", $1, $2, 2)"#)
    }

    @Test func `regexp_substr fills the start before an occurrence`() {
        let expression: some QueryExpression<String?> = title.regexpSubstr("a+", occurrence: 2)
        #expect(PostgreSQL().render(expression.queryFragment).sql == #"regexp_substr("documents"."title", $1, 1, 2)"#)
    }

    @Test func `ilike filters a select`() {
        let sql = PostgreSQL().render(PatternFixtures.Document.where { $0.title.ilike("%swift%") }.query).sql
        #expect(sql.contains(#"WHERE (("documents"."title" ILIKE $1))"#))
    }
}
