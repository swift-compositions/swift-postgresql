import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Text functions` {
    let name = TextFixtures.Person.columns.name
    let nickname = TextFixtures.Person.columns.nickname

    @Test func `initcap wraps the column`() {
        #expect(PostgreSQL().render(name.initcap().queryFragment) == ISO_9075.Rendering(sql: #"initcap("people"."name")"#, values: []))
    }

    @Test func `initcap keeps an optional column optional`() {
        let expression: some QueryExpression<String?> = nickname.initcap()
        #expect(PostgreSQL().render(expression.queryFragment).sql == #"initcap("people"."nickname")"#)
    }

    @Test func `char_length and bit_length`() {
        #expect(PostgreSQL().render(name.charLength().queryFragment).sql == #"char_length("people"."name")"#)
        #expect(PostgreSQL().render(name.bitLength().queryFragment).sql == #"bit_length("people"."name")"#)
        let optional: some QueryExpression<Int?> = nickname.charLength()
        #expect(PostgreSQL().render(optional.queryFragment).sql == #"char_length("people"."nickname")"#)
    }

    @Test func `lpad inlines the length and binds the fill`() {
        #expect(
            PostgreSQL().render(name.lpad(to: 10, with: "*").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"lpad("people"."name", 10, $1)"#,
                    values: [.text("*")]
                )
        )
    }

    @Test func `rpad fills with a space by default`() {
        #expect(
            PostgreSQL().render(name.rpad(to: 5).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"rpad("people"."name", 5, $1)"#,
                    values: [.text(" ")]
                )
        )
    }

    @Test func `left and right inline the count`() {
        #expect(PostgreSQL().render(name.left(3).queryFragment).sql == #"left("people"."name", 3)"#)
        #expect(PostgreSQL().render(name.right(2).queryFragment).sql == #"right("people"."name", 2)"#)
    }

    @Test func `split_part binds the delimiter`() {
        #expect(
            PostgreSQL().render(name.splitPart(delimiter: "-", field: 2).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"split_part("people"."name", $1, 2)"#,
                    values: [.text("-")]
                )
        )
    }

    @Test func `position renders the IN form`() {
        #expect(
            PostgreSQL().render(name.position(of: "an").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"position($1 IN "people"."name")"#,
                    values: [.text("an")]
                )
        )
    }

    @Test func `starts_with binds the prefix`() {
        #expect(
            PostgreSQL().render(name.startsWith("Al").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"starts_with("people"."name", $1)"#,
                    values: [.text("Al")]
                )
        )
    }

    @Test func `translate binds both character sets`() {
        #expect(
            PostgreSQL().render(name.translate(from: "ab", to: "xy").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"translate("people"."name", $1, $2)"#,
                    values: [.text("ab"), .text("xy")]
                )
        )
    }

    @Test func `overlay with and without a length`() {
        #expect(
            PostgreSQL().render(name.overlay(placing: "xx", from: 2, for: 3).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"overlay("people"."name" PLACING $1 FROM 2 FOR 3)"#,
                    values: [.text("xx")]
                )
        )
        #expect(PostgreSQL().render(name.overlay(placing: "xx", from: 2).queryFragment).sql == #"overlay("people"."name" PLACING $1 FROM 2)"#)
    }

    @Test func `reverse and repeat`() {
        #expect(PostgreSQL().render(name.reversed().queryFragment).sql == #"reverse("people"."name")"#)
        #expect(PostgreSQL().render(name.repeated(3).queryFragment).sql == #"repeat("people"."name", 3)"#)
    }

    @Test func `md5 and ascii`() {
        #expect(PostgreSQL().render(name.md5().queryFragment).sql == #"md5("people"."name")"#)
        #expect(PostgreSQL().render(name.ascii().queryFragment).sql == #"ascii("people"."name")"#)
    }

    @Test func `quoting functions`() {
        #expect(PostgreSQL().render(name.quoteLiteral().queryFragment).sql == #"quote_literal("people"."name")"#)
        #expect(PostgreSQL().render(name.quoteIdent().queryFragment).sql == #"quote_ident("people"."name")"#)
        #expect(PostgreSQL().render(nickname.quoteNullable().queryFragment).sql == #"quote_nullable("people"."nickname")"#)
    }

    @Test func `chr inlines the code`() {
        #expect(PostgreSQL().render(PostgreSQL.Text.chr(65).queryFragment) == ISO_9075.Rendering(sql: "chr(65)", values: []))
    }

    @Test func `concat_ws binds the separator and lists the values`() {
        #expect(
            PostgreSQL().render(PostgreSQL.Text.concatenate(separator: ", ", name, nickname).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"concat_ws($1, "people"."name", "people"."nickname")"#,
                    values: [.text(", ")]
                )
        )
    }

    @Test func `format binds the template and lists the arguments`() {
        #expect(
            PostgreSQL().render(PostgreSQL.Text.format("Hello %s, %s", name, 42).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"format($1, "people"."name", $2)"#,
                    values: [.text("Hello %s, %s"), .int(42)]
                )
        )
    }
}
