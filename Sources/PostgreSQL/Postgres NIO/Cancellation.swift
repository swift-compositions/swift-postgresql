#if PostgresNIO && !os(Windows)
    internal import Synchronization

    /// Whether the task that leased a connection has been cancelled, for the thread that runs its closure.
    final class Cancellation: Sendable {
        private let cancelled = Atomic<Bool>(false)
    }

    extension Cancellation {
        var isCancelled: Bool { cancelled.load(ordering: .acquiring) }

        func cancel() { cancelled.store(true, ordering: .releasing) }
    }
#endif
