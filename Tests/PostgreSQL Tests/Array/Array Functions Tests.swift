import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Array operators` {
    let article = ArrayFixtures.Article.columns

    @Test func `containment binds the other array`() {
        let rendering = PostgreSQL().render(article.tags.contains(PostgreSQL.Array<String>(["swift"])).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"("articles"."tags" @> $1)"#,
                    values: [.array([.text("swift")], of: .text)]
                )
        )
    }

    @Test func `containment and overlap compare two columns`() {
        #expect(
            PostgreSQL().render(article.tags.isContained(by: article.aliases).queryFragment).sql
                == #"("articles"."tags" <@ "articles"."aliases")"#
        )
        #expect(
            PostgreSQL().render(article.aliases.overlaps(article.tags).queryFragment).sql
                == #"("articles"."aliases" && "articles"."tags")"#
        )
    }

    @Test func `concatenation keeps the array type`() {
        #expect(
            PostgreSQL().render(article.tags.concatenated(with: article.aliases).queryFragment).sql
                == #"("articles"."tags" || "articles"."aliases")"#
        )
    }
}

@Suite struct `Array functions` {
    let article = ArrayFixtures.Article.columns

    @Test func `element edits bind the element`() {
        #expect(
            PostgreSQL().render(article.tags.appending("new").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"array_append("articles"."tags", $1)"#,
                    values: [.text("new")]
                )
        )
        #expect(
            PostgreSQL().render(article.tags.prepending("first").queryFragment).sql
                == #"array_prepend($1, "articles"."tags")"#
        )
        #expect(
            PostgreSQL().render(article.tags.removing("old").queryFragment).sql
                == #"array_remove("articles"."tags", $1)"#
        )
        #expect(
            PostgreSQL().render(article.tags.replacing("old", with: "new").queryFragment).sql
                == #"array_replace("articles"."tags", $1, $2)"#
        )
    }

    @Test func `positions inline their start`() {
        #expect(
            PostgreSQL().render(article.tags.position(of: "swift").queryFragment).sql
                == #"array_position("articles"."tags", $1)"#
        )
        #expect(
            PostgreSQL().render(article.tags.position(of: "swift", from: 2).queryFragment).sql
                == #"array_position("articles"."tags", $1, 2)"#
        )
        #expect(
            PostgreSQL().render(article.tags.positions(of: "swift").queryFragment).sql
                == #"array_positions("articles"."tags", $1)"#
        )
    }

    @Test func `subscripts and slices are one-based`() {
        #expect(PostgreSQL().render(article.tags.element(at: 1).queryFragment).sql == #"("articles"."tags")[1]"#)
        #expect(PostgreSQL().render(article.tags.slice(2...3).queryFragment).sql == #"("articles"."tags")[2:3]"#)
    }

    @Test func `sizes inline their dimension`() {
        #expect(PostgreSQL().render(article.tags.cardinality().queryFragment).sql == #"cardinality("articles"."tags")"#)
        #expect(PostgreSQL().render(article.tags.length().queryFragment).sql == #"array_length("articles"."tags", 1)"#)
        #expect(PostgreSQL().render(article.aliases.upperBound().queryFragment).sql == #"array_upper("articles"."aliases", 1)"#)
        #expect(PostgreSQL().render(article.tags.dimensionCount().queryFragment).sql == #"array_ndims("articles"."tags")"#)
    }

    @Test func `text conversion binds its separator and null text`() {
        #expect(
            PostgreSQL().render(article.tags.arrayToString(separator: ", ").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"array_to_string("articles"."tags", $1)"#,
                    values: [.text(", ")]
                )
        )
        #expect(
            PostgreSQL().render(article.title.stringToArray(separator: " ", null: "-").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"string_to_array("articles"."title", $1, $2)"#,
                    values: [.text(" "), .text("-")]
                )
        )
    }

    @Test func `a filled array inlines its length`() {
        #expect(
            PostgreSQL().render(PostgreSQL.Array<Int>.fill(0, count: 3).queryFragment)
                == ISO_9075.Rendering(
                    sql: "array_fill($1, ARRAY[3])",
                    values: [.int(0)]
                )
        )
    }

    @Test func `unnest expands an array into rows`() {
        #expect(PostgreSQL().render(PostgreSQL.Series.unnest(article.tags).queryFragment).sql == #"unnest("articles"."tags")"#)
    }

    @Test func `membership uses a quantified comparison`() {
        let rendering = PostgreSQL().render(article.title.eq(.any(article.tags)).queryFragment)
        #expect(rendering.sql == #"("articles"."title") = ANY ("articles"."tags")"#)
    }
}
