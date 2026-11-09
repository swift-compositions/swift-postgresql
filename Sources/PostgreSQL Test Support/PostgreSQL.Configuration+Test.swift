public import PostgreSQL
internal import Foundation

extension PostgreSQL.Configuration {
    /// The configuration the test suites connect with: ``test(environment:)`` of the process environment.
    public static var test: Self {
        test(environment: ProcessInfo.processInfo.environment)
    }

    /// `POSTGRES_HOST` (default `localhost`), `POSTGRES_PORT` (5432), `POSTGRES_USER` (default the current user,
    /// `USER`, as libpq does, since a local server's role is named after the account that installed it), `POSTGRES_PASSWORD`,
    /// `POSTGRES_DB` (`swift_postgresql_test`), and TLS from `POSTGRES_SSLMODE` (`disable`, `require`,
    /// `verify-full`; default `disable`) with extra roots from `POSTGRES_SSLROOTCERT`. A value that can't be read
    /// stops the test run.
    public static func test(environment: [String: String]) -> Self {
        var tls = TLS.disabled
        switch environment["POSTGRES_SSLMODE"] {
        case nil, "disable": break
        case "require": tls = .required
        case "verify-full": tls = .verified
        case let mode?: preconditionFailure("POSTGRES_SSLMODE \(mode) is none of disable, require, verify-full")
        }
        if let file = environment["POSTGRES_SSLROOTCERT"] {
            tls.rootCertificates = [.file(file)]
        }
        return Self(
            host: environment["POSTGRES_HOST"] ?? "localhost",
            port: environment["POSTGRES_PORT"].flatMap(Int.init) ?? 5432,
            user: environment["POSTGRES_USER"] ?? environment["USER"] ?? "postgres",
            password: environment["POSTGRES_PASSWORD"],
            database: environment["POSTGRES_DB"] ?? "swift_postgresql_test",
            tls: tls
        )
    }
}
