#if PostgresNIO && !os(Windows)
    internal import PostgreSQL_SQL
    internal import Logging
    internal import NIOCore
    internal import NIOPosix
    package import PostgresNIO
    internal import Synchronization

    extension PostgreSQL.Database {
        /// What a database runs on: the engine's client, the task that runs it, the threads closures run on, and the
        /// clock its acquire timeout runs on.
        package final class Engine: Sendable {
            let configuration: PostgreSQL.Configuration
            package let client: PostgresClient
            let threads: NIOThreadPool
            let logger: Logger
            let runner: Task<Void, Never>
            let closed = Atomic<Bool>(false)
            let attempts: Attempts
            let clock: any Clock<Duration>

            init(
                configuration: PostgreSQL.Configuration,
                clock: some Clock<Duration>,
                client: PostgresClient.Configuration
            ) {
                let attempts = Attempts()
                let logger = Logger(label: "PostgreSQL", factory: { _ in Listener(attempts: attempts) })
                let client = PostgresClient(configuration: client, backgroundLogger: logger)
                self.attempts = attempts
                self.configuration = configuration
                self.client = client
                self.logger = logger
                self.clock = clock
                self.threads = NIOThreadPool(numberOfThreads: max(1, configuration.poolSize))
                self.threads.start()
                self.runner = Task { await client.run() }
            }

            deinit {
                runner.cancel()
                threads.shutdownGracefully { _ in }
            }
        }
    }

    extension PostgreSQL.Database.Engine {
        func close() async {
            guard !closed.exchange(true, ordering: .acquiringAndReleasing) else { return }
            runner.cancel()
            await runner.value
            try? await threads.shutdownGracefully()
        }
    }
#endif
