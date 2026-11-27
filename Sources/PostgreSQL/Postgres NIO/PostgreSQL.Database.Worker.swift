#if PostgresNIO && !os(Windows)
    internal import ISO_9075_Call_Level_Interface
    internal import PostgreSQL_SQL
    internal import Synchronization
    internal import Thread_Actor

    extension PostgreSQL.Database {
        /// What a scope failed with: the database's own failure, or what the body threw. A body that let one of the
        /// connection's errors out carries the ``PostgreSQL/Error`` that error was, SQLSTATE code included.
        enum Fault<Thrown: Swift.Error>: Swift.Error {
            case database(PostgreSQL.Error)
            case body(Thrown, original: PostgreSQL.Error?)
        }

        /// One thread that bodies run on: an actor whose executor is a thread of its own. A body is synchronous and
        /// its statements block, so it runs here and never on a thread of the cooperative pool. The body runs inside
        /// the caller's task, so it can ask whether that task was cancelled.
        actor Worker {
            nonisolated let executor: Kernel.Thread.Executor

            init() {
                self.executor = Kernel.Thread.Executor()
            }

            nonisolated var unownedExecutor: UnownedSerialExecutor {
                unsafe executor.asUnownedSerialExecutor()
            }

            /// Opens `begin`, lends the connection to `body`, and ends with `end`; rolls back when `body` throws or
            /// the task was cancelled meanwhile. The body comes in by `sending` and its result leaves by `sending`.
            func run<Value, Thrown: Swift.Error>(
                on core: PostgreSQL.Connection.Core,
                begin: ISO.`9075`.Fragment?,
                end: ISO.`9075`.Fragment?,
                _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
            ) throws(Fault<Thrown>) -> sending Value {
                do throws(PostgreSQL.Error) {
                    if let begin { try core.run(begin) }
                } catch {
                    throw .database(error)
                }
                let value: Value
                do throws(Thrown) {
                    value = try body(PostgreSQL.Connection(core))
                } catch {
                    let original = (error as? ISO.`9075`.Error).flatMap { core.failures.original(of: $0) }
                    if begin != nil, let failure = Self.rollback(core, after: "\(error)") { throw .database(failure) }
                    throw .body(error, original: original)
                }
                guard let end else { return value }
                if Task.isCancelled {
                    let cancelled = PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled: rolled back")
                    throw .database(Self.rollback(core, after: "\(cancelled)") ?? cancelled)
                }
                do throws(PostgreSQL.Error) {
                    try core.run(end)
                } catch {
                    throw .database(Self.rollback(core, after: "\(error)") ?? error)
                }
                return value
            }

            /// Rolls back. When that fails, closes the connection and gives the failure to throw in place of `reason`.
            private static func rollback(_ core: PostgreSQL.Connection.Core, after reason: Swift.String) -> PostgreSQL.Error? {
                do throws(PostgreSQL.Error) {
                    try core.run("ROLLBACK")
                    return nil
                } catch {
                    return PostgreSQL.Error(
                        kind: .closed,
                        message: "\(reason); ROLLBACK failed (\(error)) and \(core.discard())"
                    )
                }
            }
        }

        /// The database's threads: one per connection of the pool, so a leased connection always finds one free.
        final class Workers: Sendable {
            private let workers: [Worker]
            private let idle: Mutex<[Int]>
            private let next = Atomic<Int>(0)

            init(count: Int) {
                self.workers = (0..<count).map { _ in Worker() }
                self.idle = Mutex(Array(0..<count))
            }

            struct Lease {
                let worker: Worker
                let index: Int?
            }

            func lease() -> Lease {
                if let index = idle.withLock({ $0.popLast() }) { return Lease(worker: workers[index], index: index) }
                return Lease(worker: workers[next.add(1, ordering: .relaxed).oldValue % workers.count], index: nil)
            }

            func release(_ lease: Lease) {
                if let index = lease.index { idle.withLock { $0.append(index) } }
            }
        }

        /// Fires once. A wait for it is not ended by cancellation: what waits holds a connection that a body may
        /// still be using.
        final class Signal: Sendable {
            private let state = Mutex<State>(.waiting(nil))

            enum State {
                case waiting(CheckedContinuation<Void, Never>?)
                case fired
            }

            func fire() {
                let waiter: CheckedContinuation<Void, Never>? = state.withLock { state in
                    defer { state = .fired }
                    if case .waiting(let waiter) = state { return waiter }
                    return nil
                }
                waiter?.resume()
            }

            func wait() async {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    let fired = state.withLock { state in
                        if case .fired = state { return true }
                        state = .waiting(continuation)
                        return false
                    }
                    if fired { continuation.resume() }
                }
            }
        }
    }
#endif
