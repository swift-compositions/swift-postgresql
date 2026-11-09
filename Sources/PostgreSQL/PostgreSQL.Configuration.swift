public import PostgreSQL_SQL

extension PostgreSQL {
    /// Where a ``PostgreSQL/Database`` connects, as whom, how securely, and how many connections it keeps.
    ///
    /// Made directly, from a `postgres://` URL with ``init(url:)``, or from the process environment with
    /// ``init(environment:)``.
    public struct Configuration: Sendable, Hashable {
        /// The server's host name or address.
        public var host: String

        /// The server's port. 5432 by default.
        public var port: Int

        /// The role to connect as.
        public var user: String

        /// The role's password, when the server asks for one.
        public var password: String?

        /// The database to connect to.
        public var database: String

        /// Whether, and how strictly, the connection is encrypted. ``TLS/disabled`` by default.
        public var tls: TLS

        /// The most connections the database holds open at once. Work beyond that many waits for one to come free.
        public var poolSize: Int

        /// How long opening a connection may take before it fails with ``PostgreSQL/Error/Kind/timeout``.
        public var connectTimeout: Duration

        /// How long a read or write waits for a free connection before it fails with
        /// ``PostgreSQL/Error/Kind/timeout``.
        public var acquireTimeout: Duration

        public init(
            host: String,
            port: Int = 5432,
            user: String,
            password: String? = nil,
            database: String,
            tls: TLS = .disabled,
            poolSize: Int = 10,
            connectTimeout: Duration = .seconds(10),
            acquireTimeout: Duration = .seconds(30)
        ) {
            self.host = host
            self.port = port
            self.user = user
            self.password = password
            self.database = database
            self.tls = tls
            self.poolSize = poolSize
            self.connectTimeout = connectTimeout
            self.acquireTimeout = acquireTimeout
        }
    }
}
