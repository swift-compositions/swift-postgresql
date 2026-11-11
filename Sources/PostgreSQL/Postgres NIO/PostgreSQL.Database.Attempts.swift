#if PostgresNIO && !os(Windows)
    public import PostgreSQL_SQL
    internal import Logging
    internal import Synchronization

    extension PostgreSQL.Database {
        /// Counts the pool's failed attempts to open a connection, and wakes whoever waits for the next one.
        ///
        /// The engine's pool retries a failed connection without end and tells only its logger, so a lease would
        /// otherwise wait out its whole timeout behind a wrong password. The database listens to that logger.
        final class Attempts: Sendable {
            private struct State {
                var failures = 0
                var waiters: [Int: CheckedContinuation<Void, Never>] = [:]
                var next = 0
            }

            private let state = Mutex(State())

            var failures: Int { state.withLock { $0.failures } }

            func failed() {
                let waiters = state.withLock { state in
                    state.failures += 1
                    defer { state.waiters = [:] }
                    return state.waiters.values
                }
                for waiter in waiters { waiter.resume() }
            }

            /// Returns once more than `count` attempts have failed, or the task is cancelled.
            func failure(after count: Int) async {
                let id = state.withLock { state in
                    defer { state.next += 1 }
                    return state.next
                }
                await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        let resume = state.withLock { state in
                            if state.failures > count || Task.isCancelled { return true }
                            state.waiters[id] = continuation
                            return false
                        }
                        if resume { continuation.resume() }
                    }
                } onCancel: {
                    let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
                    waiter?.resume()
                }
            }
        }

        /// The engine's logger: it drops everything, but tells ``Attempts`` of every failed connection attempt.
        struct Listener: LogHandler {
            let attempts: Attempts
            var metadata: Logger.Metadata = [:]
            var logLevel: Logger.Level = .info

            subscript(metadataKey key: String) -> Logger.Metadata.Value? {
                get { metadata[key] }
                set { metadata[key] = newValue }
            }

            func log(event: LogEvent) {
                if event.message.description == "Connection creation failed" {
                    attempts.failed()
                }
            }
        }
    }
#endif
