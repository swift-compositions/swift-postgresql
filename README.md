# swift-postgresql

Use this package when your queries are written with swift-sql and run against PostgreSQL, or when you need PostgreSQL features the standard SQL layer doesn't have: arrays, JSONB, full-text search, window functions, triggers and LISTEN/NOTIFY. Start from `PostgreSQL` as the dialect that renders statements, and `PostgreSQL.Database` to run them over PostgresNIO. For tests that need a real server, use `PostgreSQL.TestDatabase.Scope` from `PostgreSQL Test Support`. If your database is SQLite, use swift-sqlite.

## Laws

- Bound values are numbered `$1`, `$2` and so on. When a value is inlined instead, an instant becomes a UTC `TIMESTAMPTZ` literal, bytes become a hex `BYTEA` literal, and an array becomes `ARRAY[...]` cast to its element type.
- Nothing runs until `PostgreSQL.Database.run()` is running, because it drives the connection pool. Each body is synchronous and holds one pooled connection on the thread pool while it runs.
- `PostgreSQL.Database.read(_:)` runs its body in a read-only transaction and `PostgreSQL.Database.write(_:)` in a read-write one. Both commit when the body returns and roll back when it throws. If the rollback itself fails, the connection is closed and the error says so. `PostgreSQL.Database.withRollback(_:)` always rolls back, and `PostgreSQL.Database.writeWithoutTransaction(_:)` opens no transaction.
- `PostgreSQL.Connection.withSavepoint(_:_:)` releases its savepoint when the body returns. When the body throws it rolls back to the savepoint and rethrows, and the outer transaction carries on.
- An empty statement is not sent to the server: executing it affects 0 rows and fetching it returns nothing.
- Instants are bound as `TIMESTAMPTZ` with microsecond precision, whatever the session's time zone. Finer digits are dropped toward the earlier microsecond. A `date` column reads as midnight UTC.
- An array binds as one value only if every element has the array's kind and none is null. Decimal and JSON arrays can't be bound. Arrays decode from the one-dimensional text form only, and a null element fails for a non-optional element type.
- A decimal binds only if its text is a number, `NaN` or `Infinity`.
- `PostgreSQL.JSONB<Value>` encodes with sorted keys and dates as ISO 8601 with fractional seconds. It decodes PostgreSQL's own timestamps, with or without a zone offset.
- `PostgreSQL.Cursor<Element>` declares a forward-only cursor and fetches `batch` rows at a time. A cursor lives only inside a transaction, so use it within `read` or `write`.
- `fetchOne` adds `LIMIT 1` when the statement selects whole rows of a table. A statement that selects chosen columns is fetched in full and its first row kept.
- `PostgreSQL.Configuration.init(environment:tls:)` reads each `DATABASE_` variable before its `POSTGRES_` counterpart. The password may be missing. The pool closes connections idle for 60 seconds and sends `SELECT 1` every 30 seconds to keep them alive.
- `PostgreSQL.Notification.Channel.setUp(on:_:timing:includingOld:)` installs a trigger that sends each insert, update and delete after it happens, with the new row and, if asked, the old one. An insert has no old row and a delete no new row. Rows travel through `row_to_json`, so a notification decodes the same way whether a trigger or `notify(_:)` sent it.
- `PostgreSQL.Database.listen(on:consume:)` holds one connection for as long as `consume` runs, and stops listening when it returns.
- `PostgreSQL.TextSearch.query(_:configuration:syntax:)` parses with the web search syntax unless told otherwise. A generated search vector treats a null source column as empty text.
- `PostgreSQL.TestDatabase.Scope` creates a database with a random name for each suite, runs the set-up statements, and drops it with `FORCE` afterwards, also when the suite fails. If no server answers at the default address and `POSTGRES_HOST` is unset, the suite is cancelled rather than failed. `PostgreSQL.Configuration.test` defaults to `localhost`, port 5432, database `swift_postgresql_test`, without TLS, and each `POSTGRES_` variable overrides its part.
