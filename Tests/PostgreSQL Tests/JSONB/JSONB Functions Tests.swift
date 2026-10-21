import Byte
import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `JSONB functions` {
    @Test func `set binds path and document`() {
        let fragment = JSONBFixtures.User.columns.settings.setting(["theme"], to: "dark").queryFragment
        #expect(PostgreSQL().render(fragment).sql == #"jsonb_set("users"."settings", $1::text[], $2::jsonb, $3)"#)
        #expect(fragment.debugDescription == #"jsonb_set("users"."settings", ARRAY['theme']::text[], '"dark"'::jsonb, TRUE)"#)
    }

    @Test func `set binds path elements rather than spelling them`() {
        let fragment = JSONBFixtures.User.columns.settings.setting(JSONBFixtures.reservedPath, to: "dark", createIfMissing: false)
            .queryFragment
        #expect(
            fragment.debugDescription
                == #"jsonb_set("users"."settings", ARRAY['a,b', 'o''brien', '}']::text[], '"dark"'::jsonb, FALSE)"#
        )
    }

    @Test func `insert binds path, document and position`() {
        let fragment = JSONBFixtures.User.columns.settings.inserting("dark", at: JSONBFixtures.reservedPath, after: true)
            .queryFragment
        #expect(PostgreSQL().render(fragment).sql == #"jsonb_insert("users"."settings", $1::text[], $2::jsonb, $3)"#)
        #expect(
            fragment.debugDescription
                == #"jsonb_insert("users"."settings", ARRAY['a,b', 'o''brien', '}']::text[], '"dark"'::jsonb, TRUE)"#
        )
    }

    @Test func `processing functions`() {
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.strippingNulls().queryFragment).sql
                == #"jsonb_strip_nulls("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.prettyFormatted().queryFragment).sql
                == #"jsonb_pretty("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.metadata.typeString().queryFragment).sql
                == #"jsonb_typeof("users"."metadata")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.arrayLength().gt(5).queryFragment)
                == ISO_9075.Rendering(sql: #"(jsonb_array_length("users"."settings")) > ($1)"#, values: [.int(5)])
        )
    }

    @Test func `path extraction functions bind a variadic text array`() {
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.extractPath(["a", "b"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"jsonb_extract_path("users"."settings", VARIADIC $1::text[])"#,
                    values: [.array([.text("a"), .text("b")], of: .text)]
                )
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.extractPathText(["a"], format: .json).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"json_extract_path_text("users"."settings", VARIADIC $1::text[])"#,
                    values: [.array([.text("a")], of: .text)]
                )
        )
    }

    @Test func `jsonpath functions cast the bound path`() {
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.pathExists("$.theme").queryFragment)
                == ISO_9075.Rendering(sql: #"jsonb_path_exists("users"."settings", $1::jsonpath)"#, values: [.text("$.theme")])
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.pathQuery("$.items[*]").queryFragment)
                == ISO_9075.Rendering(sql: #"jsonb_path_query("users"."settings", $1::jsonpath)"#, values: [.text("$.items[*]")])
        )
    }

    @Test func `set-returning functions`() {
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.arrayElements().queryFragment).sql
                == #"jsonb_array_elements("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.arrayElements(format: .json).queryFragment).sql
                == #"json_array_elements("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.arrayElementsText().queryFragment).sql
                == #"jsonb_array_elements_text("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.arrayElementsText(format: .json).queryFragment).sql
                == #"json_array_elements_text("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.each().queryFragment).sql
                == #"jsonb_each("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.eachText().queryFragment).sql
                == #"jsonb_each_text("users"."settings")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.settings.objectKeys().queryFragment).sql
                == #"jsonb_object_keys("users"."settings")"#
        )
    }

    @Test func `conversion functions`() {
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.id.toJsonb().queryFragment).sql
                == #"to_jsonb("users"."id")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.name.toJson().queryFragment).sql
                == #"to_json("users"."name")"#
        )
        #expect(
            PostgreSQL().render(JSONBFixtures.User.columns.tags.arrayToJson().queryFragment).sql
                == #"array_to_json("users"."tags")"#
        )
    }

    @Test func `build array renders its arguments in order`() {
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.buildArray(JSONBFixtures.User.columns.name, JSONBFixtures.User.columns.id).queryFragment
            ).sql == #"jsonb_build_array("users"."name", "users"."id")"#
        )
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.buildArray(JSONBFixtures.User.columns.name, format: .json).queryFragment
            ).sql == #"json_build_array("users"."name")"#
        )
        #expect(PostgreSQL().render(PostgreSQL.JSON.buildArray().queryFragment).sql == "jsonb_build_array()")
    }

    @Test func `build arrays nest`() {
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.buildArray(
                    JSONBFixtures.User.columns.name,
                    PostgreSQL.JSON.buildArray(JSONBFixtures.User.columns.id, JSONBFixtures.User.columns.name.toJsonb())
                ).queryFragment
            ).sql == #"jsonb_build_array("users"."name", jsonb_build_array("users"."id", to_jsonb("users"."name")))"#
        )
    }

    @Test func `build object binds its keys`() {
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.buildObject(("name", JSONBFixtures.User.columns.name), ("id", JSONBFixtures.User.columns.id))
                    .queryFragment
            )
                == ISO_9075.Rendering(
                    sql: #"jsonb_build_object($1, "users"."name", $2, "users"."id")"#,
                    values: [.text("name"), .text("id")]
                )
        )
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.buildObject(("name", JSONBFixtures.User.columns.name), format: .json).queryFragment
            ).sql == #"json_build_object($1, "users"."name")"#
        )
    }

    @Test func `object binds keys and values as text arrays`() {
        #expect(
            PostgreSQL().render(
                PostgreSQL.JSON.object(keys: ["name", "email"], values: ["Alice", "alice@example.com"], format: .json)
                    .queryFragment
            )
                == ISO_9075.Rendering(
                    sql: "json_object($1::text[], $2::text[])",
                    values: [
                        .array([.text("name"), .text("email")], of: .text),
                        .array([.text("Alice"), .text("alice@example.com")], of: .text),
                    ]
                )
        )
        #expect(
            PostgreSQL.JSON.object(keys: ["a,b", "}"], values: ["o'brien", "{x}"]).queryFragment.debugDescription
                == "jsonb_object(ARRAY['a,b', '}']::text[], ARRAY['o''brien', '{x}']::text[])"
        )
    }

    @Test func `row renders the table row`() {
        #expect(
            PostgreSQL().render(PostgreSQL.JSON.row(JSONBFixtures.User.self).queryFragment).sql
                == #"row_to_json("users".*)"#
        )
    }
}
