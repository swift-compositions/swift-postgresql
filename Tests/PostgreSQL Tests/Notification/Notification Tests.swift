import Byte
import ISO_9075_Call_Level_Interface
import ISO_9075_Foundation
import PostgreSQL
import RFC_4122
import SQL
import SQL_Macros
import Testing
import Time

@Suite struct `Notification channels` {
    @Test func `notify binds the channel and the payload`() {
        let rendering = PostgreSQL().render(PostgreSQL.Notification.Channel("events").notify("hello").query)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: "SELECT pg_notify($1, $2)",
                    values: [.text("events"), .text("hello")]
                )
        )
    }

    @Test func `a JSON channel encodes its payload as text`() {
        let channel = PostgreSQL.Notification.Channel<PostgreSQL.Notification.Change<TriggerFixtures.Order>>(json: "orders")
        let change = PostgreSQL.Notification.Change(
            operation: .insert,
            new: TriggerFixtures.Order(id: 1, status: "open", total: 2),
            old: nil
        )
        let rendering = PostgreSQL().render(channel.notify(change).query)
        #expect(rendering.values.last == .text(#"{"new":{"id":1,"status":"open","total":2},"operation":"INSERT"}"#))
    }

    @Test func `listening quotes the channel`() {
        let channel = PostgreSQL.Notification.Channel("Order Events")
        #expect(PostgreSQL().render(channel.listen().query).sql == #"LISTEN "Order Events""#)
        #expect(PostgreSQL().render(channel.unlisten().query).sql == #"UNLISTEN "Order Events""#)
        #expect(PostgreSQL().render(PostgreSQL.Notification.unlistenAll().query).sql == "UNLISTEN *")
    }
}

@Suite struct `Notification triggers` {
    let channel = PostgreSQL.Notification.Channel<PostgreSQL.Notification.Change<TriggerFixtures.Order>>(json: "order_changes")

    @Test func `setting up creates the function and replaces the trigger`() {
        let statements = channel.setUp(on: TriggerFixtures.Order.self).map { PostgreSQL().render($0.query).sql }
        #expect(statements.count == 3)
        #expect(statements[0].hasPrefix(#"CREATE OR REPLACE FUNCTION "orders_order_changes_notify"() RETURNS trigger"#))
        #expect(statements[0].contains("PERFORM pg_notify('order_changes', json_build_object('operation', TG_OP, 'new', CASE WHEN TG_OP <> 'DELETE' THEN row_to_json(NEW) END)::text);"))
        #expect(statements[1] == #"DROP TRIGGER IF EXISTS "orders_order_changes_trigger" ON "orders""#)
        #expect(
            statements[2]
                == #"CREATE TRIGGER "orders_order_changes_trigger" AFTER INSERT OR UPDATE OR DELETE ON "orders" FOR EACH ROW EXECUTE FUNCTION "orders_order_changes_notify"()"#
        )
    }

    @Test func `old rows are included on request`() {
        let statements = channel.setUp(on: TriggerFixtures.Order.self, [.update], includingOld: true).map { PostgreSQL().render($0.query).sql }
        #expect(statements[0].contains("'old', CASE WHEN TG_OP <> 'INSERT' THEN row_to_json(OLD) END"))
        #expect(statements[2].contains("AFTER UPDATE ON"))
    }

    @Test func `tearing down drops the trigger before the function`() {
        let statements = channel.tearDown(on: TriggerFixtures.Order.self).map { PostgreSQL().render($0.query).sql }
        #expect(
            statements == [
                #"DROP TRIGGER IF EXISTS "orders_order_changes_trigger" ON "orders""#,
                #"DROP FUNCTION IF EXISTS "orders_order_changes_notify"()"#,
            ]
        )
    }
}

@Suite struct `Notification change payloads` {
    typealias Event = NotificationFixtures.Event

    let channel = PostgreSQL.Notification.Channel<PostgreSQL.Notification.Change<Event>>(changes: "events")

    @Test func `a change decodes a row_to_json row with a zoned timestamp`() throws {
        let change = try channel.decode(
            #"""
            {"operation" : "UPDATE", "new" : {"id":1,"title":"Launch","happenedAt":"2026-01-01T01:00:00.25+01:00","reference":"0190b8a4-8a4e-7d2e-9f1c-3b2a1d0e4f5a","payload":"\\x01ff","isPublic":true,"weight":null}, "old" : null}
            """#
        )
        #expect(
            change
                == PostgreSQL.Notification.Change(
                    operation: .update,
                    new: Event(
                        id: 1,
                        title: "Launch",
                        happenedAt: try Time.Instant(secondsSinceUnixEpoch: 1_767_225_600, nanosecondFraction: 250_000_000),
                        reference: try RFC_4122.UUID("0190b8a4-8a4e-7d2e-9f1c-3b2a1d0e4f5a"),
                        payload: [Byte(bitPattern: 0x01), Byte(bitPattern: 0xFF)],
                        isPublic: true,
                        weight: nil
                    ),
                    old: nil
                )
        )
    }

    @Test func `negative offsets and whole seconds decode`() throws {
        let change = try channel.decode(
            #"""
            {"operation":"DELETE","new":null,"old":{"id":2,"title":"x","happenedAt":"2025-12-31T19:00:00-05:00","reference":null,"payload":"\\x","isPublic":false,"weight":1.5}}
            """#
        )
        #expect(change.old?.happenedAt == Time.Instant(secondsSinceUnixEpoch: 1_767_225_600))
        #expect(change.old?.payload == [Byte]())
        #expect(change.old?.weight == 1.5)
        #expect(change.new == nil)
    }

    @Test func `a payload without an operation is rejected`() {
        #expect(throws: ISO_9075.Error.self) {
            try channel.decode(#"{"new":null}"#)
        }
    }

    @Test func `notify encodes rows through row_to_json`() throws {
        let event = Event(
            id: 3,
            title: "Sent",
            happenedAt: Time.Instant(secondsSinceUnixEpoch: 0),
            reference: nil,
            payload: [],
            isPublic: true,
            weight: nil
        )
        let rendering = PostgreSQL().render(channel.notify(PostgreSQL.Notification.Change(operation: .insert, new: event, old: nil)).query)
        #expect(rendering.sql.hasPrefix(#"SELECT pg_notify($1, json_build_object('operation', $2, 'new', (SELECT row_to_json("row") FROM (SELECT $3 AS "id""#))
        #expect(rendering.sql.hasSuffix(#") AS "row"), 'old', NULL)::text)"#))
        #expect(Array(rendering.values.prefix(4)) == [ISO_9075.Value.text("events"), .text("INSERT"), .int(3), .text("Sent")])
    }
}
