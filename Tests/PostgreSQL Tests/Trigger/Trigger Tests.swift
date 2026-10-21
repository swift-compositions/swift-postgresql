import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Trigger functions` {
    @Test func `a function is created as a PL-pgSQL trigger function`() {
        let rendering = PostgreSQL().render(PostgreSQL.Function("touch").create(body: "BEGIN RETURN NEW; END;").query)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: "CREATE OR REPLACE FUNCTION \"touch\"() RETURNS trigger LANGUAGE plpgsql AS $function$\nBEGIN RETURN NEW; END;\n$function$",
                    values: []
                )
        )
    }

    @Test func `a schema qualifies the function`() {
        let rendering = PostgreSQL().render(PostgreSQL.Function("touch", schema: "audit").drop(ifExists: true, cascade: true).query)
        #expect(rendering.sql == #"DROP FUNCTION IF EXISTS "audit"."touch"() CASCADE"#)
    }
}

@Suite struct `Triggers` {
    let touch = PostgreSQL.Function("touch")

    @Test func `a trigger names its timing, events and function`() {
        let trigger = PostgreSQL.Trigger<TriggerFixtures.Order>("orders_touch", .before, [.insert, .update], executing: touch)
        #expect(
            PostgreSQL().render(trigger.create().query).sql
                == #"CREATE TRIGGER "orders_touch" BEFORE INSERT OR UPDATE ON "orders" FOR EACH ROW EXECUTE FUNCTION "touch"()"#
        )
    }

    @Test func `an update event names its columns`() {
        let trigger = PostgreSQL.Trigger<TriggerFixtures.Order>(
            "orders_status",
            .after,
            [.update(of: \.status, \.total), .delete],
            level: .statement,
            executing: touch
        )
        #expect(
            PostgreSQL().render(trigger.create(orReplace: true).query).sql
                == #"CREATE OR REPLACE TRIGGER "orders_status" AFTER UPDATE OF "status", "total" OR DELETE ON "orders" FOR EACH STATEMENT EXECUTE FUNCTION "touch"()"#
        )
    }

    @Test func `a trigger drops from its table`() {
        let trigger = PostgreSQL.Trigger<TriggerFixtures.Order>("orders_touch", .after, [.truncate], level: .statement, executing: touch)
        #expect(PostgreSQL().render(trigger.drop(ifExists: true).query).sql == #"DROP TRIGGER IF EXISTS "orders_touch" ON "orders""#)
    }
}
