public import PostgreSQL_SQL
#if PostgresNIO
    public import ISO_9075_Call_Level_Interface
    internal import Logging
    internal import NIOCore
    internal import NIOPosix
    package import PostgresNIO
    internal import Synchronization

    extension PostgreSQL {
        /// A PostgreSQL database: a pool of up to ``PostgreSQL/Configuration/poolSize`` connections to one server.
        ///
        /// Reads and writes run their closure on a connection of their own, inside a transaction, on a thread of the
        /// database's own: the closure is synchronous, and a connection's statements block that thread, never a
        /// task's. Each comes in three forms: one whose closure throws anything, one whose closure throws
        /// ``PostgreSQL/Error``, and the ones whose closure throws `ISO_9075.Error`, which are the call-level interface
        /// swift-sql's `Migrator` runs on.
        ///
        /// The database connects on first use, and closes its connections when ``close()`` is called or the last copy
        /// of it is gone.
        public struct Database: ISO_9075.Database, Sendable {
            public typealias Connection = PostgreSQL.Connection

            package let engine: Engine

            /// A database for `configuration`. Connects on first use.
            ///
            /// - Throws: ``PostgreSQL/Error/Kind/tls`` when a root certificate can't be read.
            public init(configuration: PostgreSQL.Configuration) throws(PostgreSQL.Error) {
                self.engine = Engine(
                configuration: configuration,
                client: try configuration.client(),
                probe: try configuration.connection()
            )
            }

            /// The configuration the database was made with.
            public var configuration: PostgreSQL.Configuration { engine.configuration }

            /// Closes every connection and stops the database's threads. A read or write after this throws
            /// ``PostgreSQL/Error/Kind/closed``.
            public func close() async {
                await engine.close()
            }
        }
    }

    extension PostgreSQL.Database {
        /// What a database runs on: the engine's client, the task that runs it, and the threads closures run on.
        package final class Engine: Sendable {
            let configuration: PostgreSQL.Configuration
            package let client: PostgresClient
            let threads: NIOThreadPool
            let logger: Logger
            let runner: Task<Void, Never>
            let closed = Atomic<Bool>(false)
            let attempts: Attempts
            let probe: PostgresConnection.Configuration

            init(
                configuration: PostgreSQL.Configuration,
                client: PostgresClient.Configuration,
                probe: PostgresConnection.Configuration
            ) {
                let attempts = Attempts()
                let logger = Logger(label: "PostgreSQL", factory: { _ in Listener(attempts: attempts) })
                let client = PostgresClient(configuration: client, backgroundLogger: logger)
                self.attempts = attempts
                self.probe = probe
                self.configuration = configuration
                self.client = client
                self.logger = logger
                self.threads = NIOThreadPool(numberOfThreads: max(1, configuration.poolSize))
                self.threads.start()
                self.runner = Task { await client.run() }
            }

            deinit {
                runner.cancel()
                threads.shutdownGracefully { _ in }
            }

            func close() async {
                guard !closed.exchange(true, ordering: .acquiringAndReleasing) else { return }
                runner.cancel()
                await runner.value
                try? await threads.shutdownGracefully()
            }
        }
    }

    // MARK: - Closures that throw anything

    extension PostgreSQL.Database {
        /// Runs `body` in a read-only transaction. What `body` throws comes out unchanged, but for a failure of the
        /// database itself, which comes out as ``PostgreSQL/Error``.
        @_disfavoredOverload
        public func read<T: Sendable>(_ body: @Sendable (PostgreSQL.Connection) throws -> T) async throws -> T {
            try await run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body)
        }

        /// Runs `body` in a transaction, committed when `body` returns and rolled back when it throws. What `body`
        /// throws comes out unchanged, but for a failure of the database itself, which comes out as
        /// ``PostgreSQL/Error``.
        @_disfavoredOverload
        public func write<T: Sendable>(_ body: @Sendable (PostgreSQL.Connection) throws -> T) async throws -> T {
            try await run(begin: "BEGIN", end: "COMMIT", body)
        }

        /// Runs `body` in a transaction at `isolation`.
        @_disfavoredOverload
        public func write<T: Sendable>(
            isolation: PostgreSQL.Isolation,
            _ body: @Sendable (PostgreSQL.Connection) throws -> T
        ) async throws -> T {
            try await run(begin: isolation.begin, end: "COMMIT", body)
        }

        /// Runs `body` outside of any transaction: what it executes commits statement by statement, unless it opens a
        /// transaction itself.
        @_disfavoredOverload
        public func writeWithoutTransaction<T: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws -> T
        ) async throws -> T {
            try await run(begin: nil, end: nil, body)
        }
    }

    // MARK: - Closures that throw PostgreSQL.Error

    extension PostgreSQL.Database {
        public func read<T: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(PostgreSQL.Error) -> T
        ) async throws(PostgreSQL.Error) -> T {
            try await typed { () async throws in try await run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body) }
        }

        public func write<T: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(PostgreSQL.Error) -> T
        ) async throws(PostgreSQL.Error) -> T {
            try await typed { () async throws in try await run(begin: "BEGIN", end: "COMMIT", body) }
        }

        public func write<T: Sendable>(
            isolation: PostgreSQL.Isolation,
            _ body: @Sendable (PostgreSQL.Connection) throws(PostgreSQL.Error) -> T
        ) async throws(PostgreSQL.Error) -> T {
            try await typed { () async throws in try await run(begin: isolation.begin, end: "COMMIT", body) }
        }

        public func writeWithoutTransaction<T: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(PostgreSQL.Error) -> T
        ) async throws(PostgreSQL.Error) -> T {
            try await typed { () async throws in try await run(begin: nil, end: nil, body) }
        }

        private func typed<T>(_ operation: () async throws -> T) async throws(PostgreSQL.Error) -> T {
            do {
                return try await operation()
            } catch {
                throw PostgreSQL.Error.translated(error)
            }
        }
    }

    // MARK: - Closures that throw ISO_9075.Error: the call-level interface

    extension PostgreSQL.Database {
        @_disfavoredOverload
        public func read<Value: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await interface { () async throws in try await run(begin: "BEGIN TRANSACTION READ ONLY", end: "COMMIT", body) }
        }

        @_disfavoredOverload
        public func write<Value: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await interface { () async throws in try await run(begin: "BEGIN", end: "COMMIT", body) }
        }

        @_disfavoredOverload
        public func write<Value: Sendable>(
            isolation: PostgreSQL.Isolation,
            _ body: @Sendable (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await interface { () async throws in try await run(begin: isolation.begin, end: "COMMIT", body) }
        }

        /// Runs `body` in a transaction that is always rolled back.
        public func withRollback<Value: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await interface { () async throws in try await run(begin: "BEGIN", end: "ROLLBACK", body) }
        }

        @_disfavoredOverload
        public func writeWithoutTransaction<Value: Sendable>(
            _ body: @Sendable (PostgreSQL.Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await interface { () async throws in try await run(begin: nil, end: nil, body) }
        }

        private func interface<T>(_ operation: () async throws -> T) async throws(ISO_9075.Error) -> T {
            do {
                return try await operation()
            } catch let error as ISO_9075.Error {
                throw error
            } catch {
                throw ISO_9075.Error(PostgreSQL.Error.translated(error))
            }
        }
    }

    // MARK: - Running a closure on a leased connection

    extension PostgreSQL.Database {
        /// Leases a connection, opens `begin`, runs `body` on one of the database's threads, and ends with `end`; rolls
        /// back when `body` throws or the task was cancelled meanwhile. A failure of the database comes out as
        /// ``PostgreSQL/Error``; what `body` throws comes out unchanged, but for the connection's own errors, which
        /// come out as the ``PostgreSQL/Error`` they were.
        private func run<T: Sendable>(
            begin: ISO_9075.Fragment?,
            end: ISO_9075.Fragment?,
            _ body: @Sendable (PostgreSQL.Connection) throws -> T
        ) async throws -> T {
            try await leased { connection in
                guard let begin, let end else { return try body(connection) }
                try connection.run(begin)
                let value: T
                do {
                    value = try body(connection)
                    if Task.isCancelled { throw PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled") }
                } catch {
                    do {
                        try connection.run("ROLLBACK")
                    } catch let rollback {
                        throw PostgreSQL.Error(
                            kind: .closed,
                            message: "\(error); ROLLBACK failed (\(rollback)) and \(connection.discard())"
                        )
                    }
                    throw error
                }
                try connection.run(end)
                return value
            }
        }

        /// Runs `body` on a leased connection, on one of the database's threads.
        private func leased<T: Sendable>(_ body: @Sendable (PostgreSQL.Connection) throws -> T) async throws -> T {
            guard !engine.closed.load(ordering: .acquiring) else {
                throw PostgreSQL.Error(kind: .closed, message: "the database is closed")
            }
            try Task.checkCancellation()
            let engine = engine
            return try await withoutActuallyEscaping(body) { body in
                let handoff = Handoff(body)
                defer { handoff.clear() }
                return try await engine.withConnection { postgres in
                    let connection = PostgreSQL.Connection(postgres, logger: engine.logger)
                    let result: Result<T, any Swift.Error> = try await engine.threads.runIfActive {
                        guard let body = handoff.take() else {
                            return .failure(PostgreSQL.Error(kind: .cancelled, message: "the work was abandoned"))
                        }
                        do {
                            return .success(try body(connection))
                        } catch let error as ISO_9075.Error {
                            return .failure(connection.failures.original(of: error) ?? error)
                        } catch {
                            return .failure(error)
                        }
                    }
                    return try result.get()
                }
            }
        }
    }

    extension PostgreSQL.Database.Engine {
        /// Runs `body` with a connection from the pool, waiting at most the configured acquire timeout for one. The
        /// engine's errors come out as ``PostgreSQL/Error``; what `body` throws comes out unchanged.
        func withConnection<T: Sendable>(
            _ body: @escaping @Sendable (PostgresConnection) async throws -> T
        ) async throws -> T {
            let acquired = Atomic<Bool>(false)
            let timeout = configuration.acquireTimeout
            let client = client
            return try await withThrowingTaskGroup(of: T?.self) { group in
                group.addTask {
                    let outcome: Result<T, any Swift.Error>
                    do {
                        outcome = try await client.withConnection { postgres in
                            acquired.store(true, ordering: .releasing)
                            do {
                                return .success(try await body(postgres))
                            } catch {
                                return .failure(error)
                            }
                        }
                    } catch {
                        throw PostgreSQL.Error.translated(error)
                    }
                    return try outcome.get()
                }
                let failures = attempts.failures
                group.addTask {
                    var seen = failures
                    while true {
                        await self.attempts.failure(after: seen)
                        try Task.checkCancellation()
                        seen = self.attempts.failures
                        if acquired.load(ordering: .acquiring) { return nil }
                        if let failure = await self.connectFailure() { throw failure }
                    }
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    guard acquired.load(ordering: .acquiring) else {
                        throw PostgreSQL.Error(kind: .timeout, message: "no connection came free in \(timeout)")
                    }
                    return nil
                }
                defer { group.cancelAll() }
                while let next = try await group.next() {
                    if let value = next { return value }
                }
                throw PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled")
            }
        }
    }

    extension PostgreSQL.Database.Engine {
        /// Why a connection can't be opened right now, found by opening one outside the pool; `nil` when it opens.
        func connectFailure() async -> PostgreSQL.Error? {
            do {
                let connection = try await PostgresConnection.connect(configuration: probe, id: 0, logger: logger)
                try? await connection.close()
                return nil
            } catch {
                return PostgreSQL.Error.translated(error)
            }
        }
    }

    /// Hands a closure to a thread and takes it back, so that no reference to it outlives the call that lent it:
    /// `withoutActuallyEscaping` traps when the closure is still referenced on return, and a thread pool's work item
    /// may be released after its caller resumes.
    private final class Handoff<Body: Sendable>: Sendable {
        private let body: Mutex<Body?>

        init(_ body: Body) {
            self.body = Mutex(body)
        }

        func take() -> Body? {
            body.withLock { body in
                defer { body = nil }
                return body
            }
        }

        func clear() {
            body.withLock { $0 = nil }
        }
    }

    extension PostgreSQL.Connection {
        /// Executes `fragment`, throwing what fails as ``PostgreSQL/Error``.
        func run(_ fragment: ISO_9075.Fragment) throws(PostgreSQL.Error) {
            do {
                _ = try execute(fragment)
            } catch {
                throw failures.original(of: error) ?? PostgreSQL.Error(error)
            }
        }
    }
#endif
