public import SQL

extension PostgreSQL.Notification.Channel {
    public func function<On: Table>(on table: On.Type) -> PostgreSQL.Function
    where Payload == PostgreSQL.Notification.Change<On> {
        PostgreSQL.Function("\(On.tableName)_\(name)_notify", schema: On.schemaName)
    }

    public func trigger<On: Table>(
        on table: On.Type,
        _ events: [PostgreSQL.Trigger<On>.Event] = [.insert, .update, .delete],
        timing: PostgreSQL.Trigger<On>.Timing = .after
    ) -> PostgreSQL.Trigger<On>
    where Payload == PostgreSQL.Notification.Change<On> {
        PostgreSQL.Trigger("\(On.tableName)_\(name)_trigger", timing, events, executing: function(on: table))
    }

    public func setUp<On: Table>(
        on table: On.Type,
        _ events: [PostgreSQL.Trigger<On>.Event] = [.insert, .update, .delete],
        timing: PostgreSQL.Trigger<On>.Timing = .after,
        includingOld: Bool = false
    ) -> [SQLQueryExpression<()>]
    where Payload == PostgreSQL.Notification.Change<On> {
        let notifying = trigger(on: table, events, timing: timing)
        return [
            function(on: table).create(body: body(includingOld: includingOld)),
            notifying.drop(ifExists: true),
            notifying.create(),
        ]
    }

    public func tearDown<On: Table>(on table: On.Type) -> [SQLQueryExpression<()>]
    where Payload == PostgreSQL.Notification.Change<On> {
        [
            trigger(on: table).drop(ifExists: true),
            function(on: table).drop(ifExists: true),
        ]
    }

    private func body(includingOld: Bool) -> String {
        let old = includingOld ? ", 'old', CASE WHEN TG_OP <> 'INSERT' THEN row_to_json(OLD) END" : ""
        return """
            BEGIN
              PERFORM pg_notify('\(name.replacing("'", with: "''"))', json_build_object('operation', TG_OP, 'new', CASE WHEN TG_OP <> 'DELETE' THEN row_to_json(NEW) END\(old))::text);
              RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
            END;
            """
    }
}
