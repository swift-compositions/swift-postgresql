#if PostgresNIO && !os(Windows)
    public import PostgreSQL_SQL
    public import ISO_9075_Call_Level_Interface
    internal import Logging
    internal import NIOCore
    internal import PostgresNIO
    internal import Synchronization

    extension PostgreSQL {
        /// A PostgreSQL database: a pool of up to ``PostgreSQL/Configuration/poolSize`` connections to one server.
        ///
        /// A read or a write lends a connection of the pool to its body, inside a transaction, on a thread of the
        /// database's own: the body is synchronous, and a connection's statements block that thread, never a
        /// task's. The body is `sending` and so is its result, so neither has to be Sendable; a body returns values
        /// it made, not ones it captured. Each scope comes in three forms: one whose body throws anything, one whose
        /// body throws ``PostgreSQL/Error``, and the ones of the call-level interface, whose body throws
        /// `ISO_9075.Error` or an error of its own; swift-sql's `Migrator` runs on those.
        ///
        /// The database connects on first use, and closes its connections when ``close()`` is called or the last copy
        /// of it is gone.
        public struct Database: ISO.`9075`.Database, Sendable {
            public typealias Connection = PostgreSQL.Connection

            package let engine: Engine

            /// A database for `configuration` whose acquire timeout runs on `clock`. Connects on first use.
            ///
            /// - Throws: ``PostgreSQL/Error/Kind/tls`` when a root certificate can't be read.
            public init<Timer: Clock<Duration>>(
                configuration: PostgreSQL.Configuration,
                clock: Timer = ContinuousClock()
            ) throws(PostgreSQL.Error) {
                self.engine = Engine(configuration: configuration, clock: clock, client: try configuration.client())
            }
        }
    }

    extension PostgreSQL.Database {
        /// The configuration the database was made with.
        public var configuration: PostgreSQL.Configuration { engine.configuration }

        /// Closes every connection. A read or write after this throws
        /// ``PostgreSQL/Error/Kind/closed``.
        public func close() async {
            await engine.close()
        }
    }

    // MARK: - A body that throws anything, or ``PostgreSQL/Error``

    extension PostgreSQL.Database {
        /// Runs `body` in a read-only transaction. What `body` throws comes out unchanged, but for the connection's
        /// own errors, which come out as the ``PostgreSQL/Error`` they were, as a failure of the database does.
        @_disfavoredOverload
        public nonisolated(nonsending) func read<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws -> sending T
        ) async throws -> sending T {
            do throws(Fault<any Swift.Error>) {
                return try await engine.run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw failure
                case .body(let thrown, let original): throw original ?? thrown
                }
            }
        }

        public nonisolated(nonsending) func read<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(PostgreSQL.Error) -> sending T
        ) async throws(PostgreSQL.Error) -> sending T {
            do throws(Fault<PostgreSQL.Error>) {
                return try await engine.run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure), .body(let failure, _): throw failure
                }
            }
        }

        /// Runs `body` in a transaction, committed when `body` returns and rolled back when it throws.
        @_disfavoredOverload
        public nonisolated(nonsending) func write<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws -> sending T
        ) async throws -> sending T {
            do throws(Fault<any Swift.Error>) {
                return try await engine.run(begin: "BEGIN", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw failure
                case .body(let thrown, let original): throw original ?? thrown
                }
            }
        }

        public nonisolated(nonsending) func write<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(PostgreSQL.Error) -> sending T
        ) async throws(PostgreSQL.Error) -> sending T {
            do throws(Fault<PostgreSQL.Error>) {
                return try await engine.run(begin: "BEGIN", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure), .body(let failure, _): throw failure
                }
            }
        }

        /// Runs `body` in a transaction at `isolation`.
        @_disfavoredOverload
        public nonisolated(nonsending) func write<T>(
            isolation: PostgreSQL.Isolation,
            _ body: sending (borrowing PostgreSQL.Connection) throws -> sending T
        ) async throws -> sending T {
            do throws(Fault<any Swift.Error>) {
                return try await engine.run(begin: isolation.begin, end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw failure
                case .body(let thrown, let original): throw original ?? thrown
                }
            }
        }

        public nonisolated(nonsending) func write<T>(
            isolation: PostgreSQL.Isolation,
            _ body: sending (borrowing PostgreSQL.Connection) throws(PostgreSQL.Error) -> sending T
        ) async throws(PostgreSQL.Error) -> sending T {
            do throws(Fault<PostgreSQL.Error>) {
                return try await engine.run(begin: isolation.begin, end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure), .body(let failure, _): throw failure
                }
            }
        }

        /// Runs `body` outside of any transaction: what it executes commits statement by statement, unless it opens a
        /// transaction itself.
        @_disfavoredOverload
        public nonisolated(nonsending) func writeWithoutTransaction<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws -> sending T
        ) async throws -> sending T {
            do throws(Fault<any Swift.Error>) {
                return try await engine.run(begin: nil, end: nil, body)
            } catch {
                switch error {
                case .database(let failure): throw failure
                case .body(let thrown, let original): throw original ?? thrown
                }
            }
        }

        public nonisolated(nonsending) func writeWithoutTransaction<T>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(PostgreSQL.Error) -> sending T
        ) async throws(PostgreSQL.Error) -> sending T {
            do throws(Fault<PostgreSQL.Error>) {
                return try await engine.run(begin: nil, end: nil, body)
            } catch {
                switch error {
                case .database(let failure), .body(let failure, _): throw failure
                }
            }
        }
    }

    // MARK: - The call-level interface

    extension PostgreSQL.Database {
        @_disfavoredOverload
        public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            do throws(Fault<Thrown>) {
                return try await engine.run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw .database(ISO.`9075`.Error(failure))
                case .body(let thrown, _): throw .body(thrown)
                }
            }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            do throws(Fault<Thrown>) {
                return try await engine.run(begin: "BEGIN", end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw .database(ISO.`9075`.Error(failure))
                case .body(let thrown, _): throw .body(thrown)
                }
            }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            do throws(Fault<Thrown>) {
                return try await engine.run(begin: "BEGIN", end: "ROLLBACK", body)
            } catch {
                switch error {
                case .database(let failure): throw .database(ISO.`9075`.Error(failure))
                case .body(let thrown, _): throw .body(thrown)
                }
            }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value>(
            isolation: PostgreSQL.Isolation,
            _ body: sending (borrowing PostgreSQL.Connection) throws(ISO.`9075`.Error) -> sending Value
        ) async throws(ISO.`9075`.Error) -> sending Value {
            do throws(Fault<ISO.`9075`.Error>) {
                return try await engine.run(begin: isolation.begin, end: "COMMIT", body)
            } catch {
                switch error {
                case .database(let failure): throw ISO.`9075`.Error(failure)
                case .body(let thrown, _): throw thrown
                }
            }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func writeWithoutTransaction<Value>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(ISO.`9075`.Error) -> sending Value
        ) async throws(ISO.`9075`.Error) -> sending Value {
            do throws(Fault<ISO.`9075`.Error>) {
                return try await engine.run(begin: nil, end: nil, body)
            } catch {
                switch error {
                case .database(let failure): throw ISO.`9075`.Error(failure)
                case .body(let thrown, _): throw thrown
                }
            }
        }
    }

    extension PostgreSQL.Database.Engine {
        typealias Fault = PostgreSQL.Database.Fault

        /// Leases a connection of the pool, waiting at most the configured acquire timeout for one, and runs `body`
        /// on it on one of the database's threads, between `begin` and `end`. The connection goes back to the pool
        /// when the body is over, and not earlier, also when the task is cancelled.
        nonisolated(nonsending) func run<Value, Thrown: Swift.Error>(
            begin: ISO.`9075`.Fragment?,
            end: ISO.`9075`.Fragment?,
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(Fault<Thrown>) -> sending Value {
            guard !closed.load(ordering: .acquiring) else {
                throw .database(PostgreSQL.Error(kind: .closed, message: "the database is closed"))
            }
            guard !Task.isCancelled else {
                throw .database(PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled"))
            }
            let (connections, source) = AsyncThrowingStream<PostgresConnection, any Swift.Error>.makeStream()
            let released = PostgreSQL.Database.Signal()
            let acquired = PostgreSQL.Database.Flag()
            let timeout = configuration.acquireTimeout
            let (client, clock, attempts) = (client, clock, attempts)

            // Holds the lease: it ends when `released` fires, which is when the body is over.
            let holder = Task {
                do {
                    try await client.withConnection { postgres in
                        acquired.set()
                        source.yield(postgres)
                        await released.wait()
                    }
                    source.finish()
                } catch {
                    source.finish(throwing: PostgreSQL.Error.translated(error))
                }
            }
            // The pool retries a failed connection without end: a lease that waits learns why from outside it.
            let failures = attempts.failures
            let watcher = Task {
                var seen = failures
                while !Task.isCancelled {
                    await attempts.failure(after: seen)
                    if Task.isCancelled || acquired.isSet { return }
                    seen = attempts.failures
                    if let failure = await self.connectFailure() {
                        source.finish(throwing: failure)
                        return
                    }
                }
            }
            let timer = Task {
                do { try await clock.sleep(for: timeout) } catch { return }
                if !acquired.isSet {
                    source.finish(throwing: PostgreSQL.Error(kind: .timeout, message: "no connection came free in \(timeout)"))
                }
            }
            defer {
                released.fire()
                watcher.cancel()
                timer.cancel()
            }

            var iterator = connections.makeAsyncIterator()
            let leased: PostgresConnection?
            do {
                leased = try await iterator.next()
            } catch {
                holder.cancel()
                throw .database(PostgreSQL.Error.translated(error))
            }
            guard let leased else {
                holder.cancel()
                throw .database(PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled"))
            }
            let thread = workers.lease()
            defer { workers.release(thread) }
            return try await thread.worker.run(
                on: PostgreSQL.Connection.Core(leased, logger: logger), begin: begin, end: end, body)
        }
    }

    extension PostgreSQL.Database {
        /// Set once, read from another task.
        final class Flag: Sendable {
            private let value = Atomic<Bool>(false)

            var isSet: Bool { value.load(ordering: .acquiring) }

            func set() { value.store(true, ordering: .releasing) }
        }
    }

    extension PostgreSQL.Database.Engine {
        /// Why a connection can't be opened right now, found by opening one outside the pool; `nil` when it opens. A
        /// configuration the engine can't connect with, such as an unreadable root certificate, is that reason too.
        func connectFailure() async -> PostgreSQL.Error? {
            do {
                let connection = try await PostgresConnection.connect(configuration: try configuration.connection(), id: 0, logger: logger)
                try? await connection.close()
                return nil
            } catch {
                return PostgreSQL.Error.translated(error)
            }
        }
    }
#endif
