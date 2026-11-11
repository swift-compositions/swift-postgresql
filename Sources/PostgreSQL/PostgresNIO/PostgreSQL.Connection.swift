public import PostgreSQL_SQL
#if PostgresNIO && !os(Windows)
    public import ISO_9075_Call_Level_Interface
    internal import Logging
    internal import NIOCore
    package import PostgresNIO
    internal import Synchronization

    extension PostgreSQL {
        /// One open connection, for the duration of a ``PostgreSQL/Database`` read or write: what its closure is
        /// given, and what every typed statement executes against.
        ///
        /// A connection is valid only inside the closure it was given to; it must not escape it.
        public struct Connection: ISO_9075.Connection, Sendable {
            public let dialect = PostgreSQL()
            package let postgres: PostgresConnection
            let logger: Logger
            let failures: Failures

            package init(_ postgres: PostgresConnection, logger: Logger) {
                self.postgres = postgres
                self.logger = logger
                self.failures = Failures()
            }

            public func execute(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> Int {
                statement.sql.isEmpty ? 0 : try result(statement).metadata.rows ?? 0
            }

            public func fetchAll<Value>(
                _ statement: ISO_9075.Rendering,
                decode: (PostgreSQL.Row) throws(ISO_9075.Error) -> Value
            ) throws(ISO_9075.Error) -> [Value] {
                statement.sql.isEmpty
                    ? []
                    : try result(statement).rows.map { row throws(ISO_9075.Error) in try decode(PostgreSQL.Row(row)) }
            }

            /// Closes the connection, so the pool opens a new one in its place: for a connection whose transaction
            /// state is unknown.
            func discard() -> String {
                do {
                    try waiting(for: postgres.close(), statement: nil)
                    return "the connection was closed"
                } catch {
                    return "closing the connection failed: \(error)"
                }
            }

            func result(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> PostgresQueryResult {
                let query = try PostgresQuery(statement)
                do {
                    return try waiting(for: postgres.query(query, logger: logger), statement: statement.sql)
                } catch {
                    let failure = PostgreSQL.Error.translated(error, statement: statement.sql)
                    let reported = ISO_9075.Error(failure)
                    failures.record(failure, as: reported)
                    throw reported
                }
            }

            /// Blocks until `future` completes, or until the connection closes, whichever is first.
            ///
            /// When the server ends a TLS connection while a statement runs, PostgresNIO can close the channel
            /// without failing that statement's future (#26), and a bare `wait()` then blocks its thread for ever.
            func waiting<Value: Sendable>(for future: EventLoopFuture<Value>, statement: String?) throws -> Value {
                let promise = postgres.eventLoop.makePromise(of: Value.self)
                future.cascade(to: promise)
                postgres.closeFuture.whenComplete { _ in
                    promise.fail(
                        PostgreSQL.Error(
                            kind: .closed,
                            message: "the connection closed before the server answered",
                            statement: statement
                        )
                    )
                }
                return try promise.futureResult.wait()
            }
        }
    }

    extension PostgreSQL.Connection {
        /// The server's errors this connection reported as `ISO_9075.Error`, kept so that a read or write whose closure
        /// lets one escape throws it as the ``PostgreSQL/Error`` it was, SQLSTATE code included.
        final class Failures: Sendable {
            private let last = Mutex<(PostgreSQL.Error, ISO_9075.Error)?>(nil)

            func record(_ failure: PostgreSQL.Error, as reported: ISO_9075.Error) {
                last.withLock { $0 = (failure, reported) }
            }

            /// The ``PostgreSQL/Error`` that `error` reported, when it is the last one this connection threw.
            func original(of error: ISO_9075.Error) -> PostgreSQL.Error? {
                last.withLock { last in last.flatMap { $0.1 == error ? $0.0 : nil } }
            }
        }
    }

    extension PostgreSQL.Connection {
        public func withSavepoint<Value>(
            _ name: String,
            _ body: (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) throws(ISO_9075.Error) -> Value {
            let savepoint = ISO_9075.Identifier(name)
            _ = try execute("SAVEPOINT \(savepoint)")
            do {
                let value = try body(self)
                _ = try execute("RELEASE SAVEPOINT \(savepoint)")
                return value
            } catch {
                do {
                    _ = try execute("ROLLBACK TO SAVEPOINT \(savepoint)")
                } catch let rollback {
                    throw .transaction("\(error); rolling back to savepoint \(name) failed: \(rollback)")
                }
                throw error
            }
        }

        public func withSavepoint<Value>(
            _ body: (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) throws(ISO_9075.Error) -> Value {
            try withSavepoint("savepoint_\(PostgreSQL.Connection.names.add(1, ordering: .relaxed).newValue)", body)
        }

        static let names = Atomic<Int>(0)
    }
#endif
