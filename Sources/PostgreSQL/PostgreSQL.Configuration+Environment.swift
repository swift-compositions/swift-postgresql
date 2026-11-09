public import PostgreSQL_SQL

extension PostgreSQL.Configuration {
    /// The configuration the environment names: `DATABASE_URL` when it is set, read by ``init(url:)``; otherwise the
    /// host, port, user, password and database from `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`,
    /// `DATABASE_PASSWORD` and `DATABASE_NAME`, each falling back to `POSTGRES_HOST`, `POSTGRES_PORT`,
    /// `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_DB`. TLS comes from `DATABASE_SSLMODE` or
    /// `POSTGRES_SSLMODE` (`disable`, `require`, `verify-full`) and `DATABASE_SSLROOTCERT` or `POSTGRES_SSLROOTCERT`.
    ///
    /// - Throws: ``Error/missing(variable:)`` naming a variable that has to be set, ``Error/invalidPort(_:)``, or the
    ///   URL's ``Error/invalidURL(_:_:)``.
    public init(environment: [String: String]) throws(Error) {
        if let url = environment["DATABASE_URL"] {
            try self.init(url: url)
            return
        }
        func value(_ names: String...) throws(Error) -> String {
            guard let value = names.lazy.compactMap({ environment[$0] }).first else {
                throw .missing(variable: names.joined(separator: " or "))
            }
            return value
        }
        let port = try value("DATABASE_PORT", "POSTGRES_PORT")
        guard let number = Int(port), (1...65535).contains(number) else { throw .invalidPort(port) }
        var tls = TLS.disabled
        if let mode = environment["DATABASE_SSLMODE"] ?? environment["POSTGRES_SSLMODE"] {
            tls.mode = try Self.mode(mode)
        }
        if let file = environment["DATABASE_SSLROOTCERT"] ?? environment["POSTGRES_SSLROOTCERT"], file != "system" {
            tls.rootCertificates = [.file(file)]
        }
        self.init(
            host: try value("DATABASE_HOST", "POSTGRES_HOST"),
            port: number,
            user: try value("DATABASE_USER", "POSTGRES_USER"),
            password: environment["DATABASE_PASSWORD"] ?? environment["POSTGRES_PASSWORD"],
            database: try value("DATABASE_NAME", "POSTGRES_DB"),
            tls: tls
        )
    }
}
