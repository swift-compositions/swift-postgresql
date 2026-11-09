import Byte
import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `JSONB operators` {
    @Test func `field binds the key`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.field("theme").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" -> $1)"#, values: [.text("theme")])
        )
    }

    @Test func `field as text binds the key`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.fieldAsText("theme").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" ->> $1)"#, values: [.text("theme")])
        )
    }

    @Test func `fields chain`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.field("preferences").field("ui").fieldAsText("theme").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"((("users"."settings" -> $1) -> $2) ->> $3)"#,
                    values: [.text("preferences"), .text("ui"), .text("theme")]
                )
        )
    }

    @Test func `element binds an integer index`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.element(at: 0).queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" -> $1::integer)"#, values: [.int(0)])
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.elementAsText(at: 1).queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" ->> $1::integer)"#, values: [.int(1)])
        )
    }

    @Test func `path extraction binds a text array`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.value(at: ["address", "city"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("users"."settings" #> $1::text[])"#,
                    values: [.array([.text("address"), .text("city")], of: .text)]
                )
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.valueAsText(at: ["contact", "email"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("users"."settings" #>> $1::text[])"#,
                    values: [.array([.text("contact"), .text("email")], of: .text)]
                )
        )
    }

    @Test func `path extraction binds elements rather than spelling them`() {
        #expect(
            JSONBFixtures.User.columns.settings.value(at: JSONBFixtures.reservedPath).queryFragment.debugDescription
                == #"("users"."settings" #> ARRAY['a,b', 'o''brien', '}']::text[])"#
        )
        #expect(
            JSONBFixtures.User.columns.settings.valueAsText(at: JSONBFixtures.reservedPath).queryFragment.debugDescription
                == #"("users"."settings" #>> ARRAY['a,b', 'o''brien', '}']::text[])"#
        )
    }

    @Test func `an empty path stays a typed empty array`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.value(at: []).queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" #> $1::text[])"#, values: [.array([], of: .text)])
        )
    }

    @Test func `containment binds a jsonb document`() throws {
        let contains = JSONBFixtures.User.columns.settings.contains(["theme": "dark"]).queryFragment
        #expect(try PostgreSQL().render(contains).sql == #"("users"."settings" @> $1::jsonb)"#)
        #expect(contains.debugDescription == #"("users"."settings" @> '{"theme":"dark"}'::jsonb)"#)

        let containedBy = JSONBFixtures.User.columns.settings.isContained(by: ["theme": "dark", "language": "en"]).queryFragment
        #expect(try PostgreSQL().render(containedBy).sql == #"("users"."settings" <@ $1::jsonb)"#)
        #expect(containedBy.debugDescription == #"("users"."settings" <@ '{"language":"en","theme":"dark"}'::jsonb)"#)
    }

    @Test func `containment document binds as json`() throws {
        let values = try PostgreSQL().render(JSONBFixtures.User.columns.settings.contains(["notifications": true]).queryFragment).values
        #expect(values.count == 1)
        #expect(values.first.map { if case .json = $0 { true } else { false } } == true)
    }

    @Test func `key existence binds the key`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.hasKey("notifications").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" ? $1)"#, values: [.text("notifications")])
        )
    }

    @Test func `any and all key existence bind a text array`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.hasAny(of: ["theme", "appearance"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("users"."settings" ?| $1::text[])"#,
                    values: [.array([.text("theme"), .text("appearance")], of: .text)]
                )
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.hasAll(of: ["theme", "language"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("users"."settings" ?& $1::text[])"#,
                    values: [.array([.text("theme"), .text("language")], of: .text)]
                )
        )
    }

    @Test func `concatenation binds a jsonb document`() throws {
        let concat = JSONBFixtures.User.columns.settings.concat(["theme": "light"]).queryFragment
        #expect(try PostgreSQL().render(concat).sql == #"("users"."settings" || $1::jsonb)"#)
        #expect(concat.debugDescription == #"("users"."settings" || '{"theme":"light"}'::jsonb)"#)
    }

    @Test func `deletion by key, keys, index and path`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.removing("theme").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" - $1)"#, values: [.text("theme")])
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.removing(keys: ["a", "b"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"("users"."settings" - $1::text[])"#,
                    values: [.array([.text("a"), .text("b")], of: .text)]
                )
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.removing(at: 2).queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" - $1::integer)"#, values: [.int(2)])
        )
        #expect(
            JSONBFixtures.User.columns.settings.removing(path: JSONBFixtures.reservedPath).queryFragment.debugDescription
                == #"("users"."settings" #- ARRAY['a,b', 'o''brien', '}']::text[])"#
        )
    }

    @Test func `manipulation keeps the typed jsonb value`() throws {
        let _: PostgreSQL.JSONB<[String: String]>.Type = JSONBFixtures.queryValue(of: JSONBFixtures.User.columns.metadata.removing("k"))
        let _: PostgreSQL.JSONB<[String: String]>.Type = JSONBFixtures.queryValue(of: JSONBFixtures.User.columns.metadata.concat(["k": "v"]))
        let _: [Byte].Type = JSONBFixtures.queryValue(of: JSONBFixtures.User.columns.settings.removing(at: 0))
        let _: [Byte]?.Type = JSONBFixtures.queryValue(of: JSONBFixtures.User.columns.preferences.removing("k"))
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.metadata.removing("k").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."metadata" - $1)"#, values: [.text("k")])
        )
    }

    @Test func `jsonpath operators cast the bound path`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.jsonPathExists("$.theme").queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" @? $1::jsonpath)"#, values: [.text("$.theme")])
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.settings.jsonPathMatch(#"$.age > 18"#).queryFragment)
                == ISO_9075.Rendering(sql: #"("users"."settings" @@ $1::jsonpath)"#, values: [.text("$.age > 18")])
        )
    }

    @Test func `operators combine with SQL predicates`() throws {
        let predicate = JSONBFixtures.User.columns.settings.hasKey("theme") && JSONBFixtures.User.columns.metadata.fieldAsText("status").eq("active")
        #expect(
            try PostgreSQL().render(predicate.queryFragment)
                == ISO_9075.Rendering(
                    sql: #"(("users"."settings" ? $1)) AND ((("users"."metadata" ->> $2)) = ($3))"#,
                    values: [.text("theme"), .text("status"), .text("active")]
                )
        )
    }
}
