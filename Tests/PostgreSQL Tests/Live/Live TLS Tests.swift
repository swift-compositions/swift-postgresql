#if PostgresNIO && !os(Windows)
    import Foundation
    import ISO_9075_Call_Level_Interface
    import PostgreSQL
    import PostgreSQL_Test_Support
    import Testing

    /// Against a server that requires TLS, whose certificate is for the test configuration's host name and signed by
    /// the root in `POSTGRES_SSLROOTCERT`, and that is also reachable as `POSTGRES_TLS_MISMATCHED_HOST`, a host name
    /// its certificate is not for. The `live` job's TLS leg in `.github/workflows/ci.yml` makes such a certificate for
    /// `localhost`, serves it, and adds `mismatched.test` for 127.0.0.1 to /etc/hosts.
    @Suite(
        .serialized,
        .enabled(
            if: ProcessInfo.processInfo.environment["POSTGRES_TLS_MISMATCHED_HOST"] != nil,
            "POSTGRES_TLS_MISMATCHED_HOST names no TLS server to check against"
        )
    )
    struct `Live TLS` {
        static var verified: PostgreSQL.Configuration {
            var configuration = PostgreSQL.Configuration.test
            precondition(configuration.tls.mode == .verified, "the TLS suite runs with POSTGRES_SSLMODE=verify-full")
            configuration.poolSize = 1
            configuration.acquireTimeout = .seconds(15)
            return configuration
        }

        static var mismatched: String { ProcessInfo.processInfo.environment["POSTGRES_TLS_MISMATCHED_HOST"]! }

        /// Whether the connection `configuration` opens is encrypted.
        func encrypted(_ configuration: PostgreSQL.Configuration) async throws -> Bool {
            let database = try PostgreSQL.Database(configuration: configuration)
            defer { Task { await database.close() } }
            let rows = try await database.read { connection in
                try connection.fetchAll("SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()") {
                    row throws(ISO_9075.Error) -> ISO_9075.Value in try row.value(at: 0)
                }
            }
            return rows == [.bool(true)]
        }

        func refusal(_ configuration: PostgreSQL.Configuration) async -> PostgreSQL.Error? {
            await #expect(throws: PostgreSQL.Error.self) { try await encrypted(configuration) }
        }

        @Test func `verified connects to a server whose certificate is for its host name`() async throws {
            #expect(try await encrypted(Self.verified))
        }

        @Test func `verified is refused by a server whose certificate is for another name`() async throws {
            var configuration = Self.verified
            configuration.host = Self.mismatched
            #expect(await refusal(configuration)?.kind == .tls)
        }

        @Test func `verified is refused by a server whose certificate no trusted root signed`() async throws {
            var configuration = Self.verified
            configuration.tls = .verified
            #expect(await refusal(configuration)?.kind == .tls)
        }

        @Test func `verified trusts a root given as PEM text`() async throws {
            var configuration = Self.verified
            let file = ProcessInfo.processInfo.environment["POSTGRES_SSLROOTCERT"]!
            configuration.tls = .verified(rootCertificates: [.pem(try String(contentsOfFile: file, encoding: .utf8))])
            #expect(try await encrypted(configuration))
        }

        @Test func `verified refuses an address, which has no name to check`() {
            var configuration = Self.verified
            configuration.host = "127.0.0.1"
            #expect(throws: PostgreSQL.Error.self) { try PostgreSQL.Database(configuration: configuration) }
            configuration.host = "::1"
            #expect(throws: PostgreSQL.Error.self) { try PostgreSQL.Database(configuration: configuration) }
        }

        @Test func `required connects under either name, and by address`() async throws {
            var configuration = Self.verified
            configuration.tls = .required
            #expect(try await encrypted(configuration))
            configuration.host = Self.mismatched
            #expect(try await encrypted(configuration))
            configuration.host = "127.0.0.1"
            #expect(try await encrypted(configuration))
        }

        @Test func `disabled is refused by a server that requires TLS`() async throws {
            var configuration = Self.verified
            configuration.tls = .disabled
            let error = await refusal(configuration)
            #expect(error?.kind == .authentication)
            #expect(error?.code == .invalidAuthorization)
        }

        @Test func `a root certificate that can't be read fails when the database is made`() {
            var configuration = Self.verified
            configuration.tls = .verified(rootCertificates: [.file("/nonexistent/root.pem")])
            #expect(throws: PostgreSQL.Error.self) { try PostgreSQL.Database(configuration: configuration) }
            configuration.tls = .verified(rootCertificates: [.pem("not a certificate")])
            #expect(throws: PostgreSQL.Error.self) { try PostgreSQL.Database(configuration: configuration) }
        }
    }
#endif
