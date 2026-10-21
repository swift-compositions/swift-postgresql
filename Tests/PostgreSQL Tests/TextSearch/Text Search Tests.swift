import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Text search vectors and queries` {
    let document = TextSearchFixtures.Document.columns

    @Test func `a vector inlines its configuration`() {
        let rendering = PostgreSQL().render(PostgreSQL.TextSearch.vector(document.title, configuration: .english).queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"to_tsvector('english'::regconfig, "documents"."title")"#, values: []))
    }

    @Test func `a query binds its text and defaults to web syntax`() {
        let rendering = PostgreSQL().render(PostgreSQL.TextSearch.query("swift sql", configuration: .english).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: "websearch_to_tsquery('english'::regconfig, $1)",
                    values: [.text("swift sql")]
                )
        )
    }

    @Test func `each syntax names its parser`() {
        #expect(
            PostgreSQL().render(PostgreSQL.TextSearch.query("a & b", configuration: .simple, syntax: .standard).queryFragment).sql
                == "to_tsquery('simple'::regconfig, $1)"
        )
        #expect(
            PostgreSQL().render(PostgreSQL.TextSearch.query("a b", configuration: .simple, syntax: .phrase).queryFragment).sql
                == "phraseto_tsquery('simple'::regconfig, $1)"
        )
    }

    @Test func `a configuration name is escaped as a literal`() {
        let rendering = PostgreSQL().render(
            PostgreSQL.TextSearch.vector(document.title, configuration: PostgreSQL.TextSearch.Configuration("o'hare")).queryFragment
        )
        #expect(rendering.sql == #"to_tsvector('o''hare'::regconfig, "documents"."title")"#)
    }

    @Test func `bound vectors and queries are cast`() {
        #expect(
            PostgreSQL().render(PostgreSQL.TextSearch.Vector("a:1").queryFragment)
                == ISO_9075.Rendering(
                    sql: "CAST($1 AS TSVECTOR)",
                    values: [.text("a:1")]
                )
        )
        #expect(PostgreSQL().render(PostgreSQL.TextSearch.Query("a & b").queryFragment).sql == "CAST($1 AS TSQUERY)")
    }
}

@Suite struct `Text search matching and ranking` {
    let document = TextSearchFixtures.Document.columns

    @Test func `a vector column matches a query`() {
        let rendering = PostgreSQL().render(
            document.search.matches(PostgreSQL.TextSearch.query("swift", configuration: .english)).queryFragment
        )
        #expect(rendering.sql == #"("documents"."search" @@ websearch_to_tsquery('english'::regconfig, $1))"#)
    }

    @Test func `a text column matches through a vector`() {
        let rendering = PostgreSQL().render(
            document.body.matches(PostgreSQL.TextSearch.query("swift", configuration: .english), configuration: .english).queryFragment
        )
        #expect(rendering.sql == #"(to_tsvector('english'::regconfig, "documents"."body") @@ websearch_to_tsquery('english'::regconfig, $1))"#)
    }

    @Test func `ranks inline their normalization`() {
        let query = PostgreSQL.TextSearch.query("swift", configuration: .english)
        #expect(
            PostgreSQL().render(document.search.rank(query).queryFragment).sql
                == #"ts_rank("documents"."search", websearch_to_tsquery('english'::regconfig, $1), 0)"#
        )
        #expect(
            PostgreSQL().render(document.search.coverDensityRank(query, normalization: [.logLength, .unitRange]).queryFragment).sql
                == #"ts_rank_cd("documents"."search", websearch_to_tsquery('english'::regconfig, $1), 33)"#
        )
    }

    @Test func `vector edits inline the weight`() {
        #expect(PostgreSQL().render(document.search.weighted(.a).queryFragment).sql == #"setweight("documents"."search", 'A')"#)
        #expect(PostgreSQL().render(document.search.stripped().queryFragment).sql == #"strip("documents"."search")"#)
        #expect(PostgreSQL().render(document.search.lexemeCount().queryFragment).sql == #"length("documents"."search")"#)
    }

    @Test func `queries combine`() {
        let swift = PostgreSQL.TextSearch.query("swift", configuration: .simple, syntax: .plain)
        let sql = PostgreSQL.TextSearch.query("sql", configuration: .simple, syntax: .plain)
        #expect(
            PostgreSQL().render(swift.and(sql).queryFragment).sql
                == "(plainto_tsquery('simple'::regconfig, $1) && plainto_tsquery('simple'::regconfig, $2))"
        )
        #expect(PostgreSQL().render(swift.negated().queryFragment).sql == "(!! plainto_tsquery('simple'::regconfig, $1))")
        #expect(
            PostgreSQL().render(swift.followed(by: sql, distance: 2).queryFragment).sql
                == "tsquery_phrase(plainto_tsquery('simple'::regconfig, $1), plainto_tsquery('simple'::regconfig, $2), 2)"
        )
    }

    @Test func `a headline binds its options`() {
        let rendering = PostgreSQL().render(
            document.title.headline(
                PostgreSQL.TextSearch.query("swift", configuration: .english),
                configuration: .english,
                options: PostgreSQL.TextSearch.Headline(startSelection: "<b>", stopSelection: "</b>", maxWords: 20)
            )
            .queryFragment
        )
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"ts_headline('english'::regconfig, "documents"."title", websearch_to_tsquery('english'::regconfig, $1), $2)"#,
                    values: [.text("swift"), .text(#"StartSel="<b>", StopSel="</b>", MaxWords=20"#)]
                )
        )
    }

    @Test func `a headline without options passes none`() {
        let rendering = PostgreSQL().render(
            document.title.headline(PostgreSQL.TextSearch.query("swift", configuration: .english), configuration: .english).queryFragment
        )
        #expect(rendering.values == [.text("swift")])
    }
}

@Suite struct `Text search definitions` {
    @Test func `a generated search vector weighs its sources`() {
        let rendering = PostgreSQL().render(
            TextSearchFixtures.Document.addSearchVector(
                "search",
                configuration: .english,
                sources: [.init(\.title, weight: .a), .init(\.body, weight: .b)]
            )
            .query
        )
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql:
                        #"ALTER TABLE "documents" ADD COLUMN "search" TSVECTOR GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, coalesce("title", '')), 'A') || setweight(to_tsvector('english'::regconfig, coalesce("body", '')), 'B')) STORED"#,
                    values: []
                )
        )
    }

    @Test func `a search index names its method`() {
        #expect(
            PostgreSQL().render(TextSearchFixtures.Document.createGINIndex(on: \.search).query).sql
                == #"CREATE INDEX "idx_documents_search_gin" ON "documents" USING GIN ("search")"#
        )
        #expect(
            PostgreSQL().render(TextSearchFixtures.Document.createGiSTIndex(name: "documents_search", on: \.search).query).sql
                == #"CREATE INDEX "documents_search" ON "documents" USING GIST ("search")"#
        )
    }
}
