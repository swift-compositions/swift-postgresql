#if PostgresNIO && !os(Windows)
    /// What a caller's closure threw, carried unchanged through a transaction, which rolls back on it.
    struct Raised<Thrown: Swift.Error>: Swift.Error {
        let thrown: Thrown
    }

    extension Raised {
        static func raising<T>(_ body: () throws(Thrown) -> T) throws(Raised) -> T {
            do throws(Thrown) {
                return try body()
            } catch {
                throw Raised(thrown: error)
            }
        }
    }
#endif
