import Byte
import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `JSONB indexes` {
    @Test func `gin index with the default operator class`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.createGINIndex(on: \.settings).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"CREATE INDEX "idx_users_settings_gin" ON "users" USING GIN ("settings")"#,
                    values: []
                )
        )
    }

    @Test func `gin index with the path operator class and a custom name`() throws {
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.User.createGINIndex(name: "custom_idx", on: \.metadata, operatorClass: .jsonbPathOps)
                    .queryFragment
            ).sql == #"CREATE INDEX "custom_idx" ON "users" USING GIN ("metadata" jsonb_path_ops)"#
        )
    }

    @Test func `gin index on an optional document column`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.createGINIndex(on: \.preferences).queryFragment).sql
                == #"CREATE INDEX "idx_users_preferences_gin" ON "users" USING GIN ("preferences")"#
        )
    }

    @Test func `gin index on a path`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.createGINIndex(on: \.settings, path: ["stats", "visits"]).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"CREATE INDEX "idx_users_settings_stats_visits_gin" ON "users" USING GIN (("settings" #> '{"stats","visits"}'::text[]))"#,
                    values: []
                )
        )
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.User.createGINIndex(on: \.settings, path: ["user", "city"], operatorClass: .jsonbPathOps)
                    .queryFragment
            ).sql
                == #"CREATE INDEX "idx_users_settings_user_city_gin" ON "users" USING GIN (("settings" #> '{"user","city"}'::text[]) jsonb_path_ops)"#
        )
    }

    @Test func `an index path literal quotes elements at the array layer`() throws {
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.User.createGINIndex(name: "idx_reserved", on: \.settings, path: JSONBFixtures.reservedPath)
                    .queryFragment
            ).sql
                == #"CREATE INDEX "idx_reserved" ON "users" USING GIN (("settings" #> '{"a,b","o''brien","}"}'::text[]))"#
        )
    }

    @Test func `an index path literal escapes array-literal escape characters`() throws {
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.User.createGINIndex(name: "idx_escapes", on: \.settings, path: JSONBFixtures.escapePath)
                    .queryFragment
            ).sql
                == #"CREATE INDEX "idx_escapes" ON "users" USING GIN (("settings" #> '{"a\"b","c\\d"}'::text[]))"#
        )
    }

    @Test func `an empty index path stays a typed empty array`() throws {
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.User.createGINIndex(name: "idx_empty", on: \.settings, path: []).queryFragment
            ).sql == #"CREATE INDEX "idx_empty" ON "users" USING GIN (("settings" #> '{}'::text[]))"#
        )
    }

    @Test func `btree index`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.createBTreeIndex(on: \.metadata).queryFragment).sql
                == #"CREATE INDEX "idx_users_metadata_btree" ON "users" USING BTREE ("metadata")"#
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.createBTreeIndex(name: "custom_btree", on: \.settings).queryFragment).sql
                == #"CREATE INDEX "custom_btree" ON "users" USING BTREE ("settings")"#
        )
    }
}
