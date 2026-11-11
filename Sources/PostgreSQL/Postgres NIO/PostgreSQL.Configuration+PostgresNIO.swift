#if PostgresNIO && !os(Windows)
    internal import PostgreSQL_SQL
    internal import NIOSSL
    package import PostgresNIO

    extension PostgreSQL.Configuration {
        /// The engine's configuration for this one. Reads the root certificate files, so it throws
        /// ``PostgreSQL/Error/Kind/tls`` for one that can't be read or holds no certificate.
        package func client() throws(PostgreSQL.Error) -> PostgresClient.Configuration {
            try requireNamedHostForVerifiedTLS()
            var configuration = PostgresClient.Configuration(
                host: host,
                port: port,
                username: user,
                password: password,
                database: database,
                tls: try tls.engine()
            )
            configuration.options.minimumConnections = 0
            configuration.options.maximumConnections = poolSize
            configuration.options.connectTimeout = connectTimeout
            configuration.options.connectionIdleTimeout = .seconds(60)
            configuration.options.keepAliveBehavior = .init(frequency: .seconds(30))
            if tls.mode == .verified {
                configuration.options.tlsServerName = host
            }
            return configuration
        }
    }

    extension PostgreSQL.Configuration {
        /// The engine's configuration for one connection outside the pool: the probe that finds out why the pool
        /// can't connect.
        package func connection() throws(PostgreSQL.Error) -> PostgresConnection.Configuration {
            try requireNamedHostForVerifiedTLS()
            let tls: PostgresConnection.Configuration.TLS
            if let configuration = try self.tls.configuration() {
                do {
                    tls = .require(try NIOSSLContext(configuration: configuration))
                } catch {
                    throw PostgreSQL.Error(kind: .tls, message: "\(error)")
                }
            } else {
                tls = .disable
            }
            var connection = PostgresConnection.Configuration(
                host: host,
                port: port,
                username: user,
                password: password,
                database: database,
                tls: tls
            )
            let (seconds, attoseconds) = connectTimeout.components
            connection.options.connectTimeout = .nanoseconds(seconds * 1_000_000_000 + attoseconds / 1_000_000_000)
            if self.tls.mode == .verified {
                connection.options.tlsServerName = host
            }
            return connection
        }
    }

    extension PostgreSQL.Configuration {
        /// ``TLS/Mode/verified`` checks the certificate against the host's name, and an address has none: the engine
        /// would then check no name at all. So an address with verified TLS is refused before anything connects.
        func requireNamedHostForVerifiedTLS() throws(PostgreSQL.Error) {
            guard tls.mode == .verified, isAddress(host) else { return }
            throw PostgreSQL.Error(
                kind: .tls,
                message: "verified TLS checks the server's certificate against a host name, and \(host) is an address: connect by the name the certificate is for"
            )
        }

        private func isAddress(_ host: String) -> Bool {
            if host.contains(":") { return true }
            let parts = host.split(separator: ".", omittingEmptySubsequences: false)
            return parts.count == 4 && parts.allSatisfy { part in UInt8(part) != nil }
        }
    }

    extension PostgreSQL.Configuration.TLS {
        package func engine() throws(PostgreSQL.Error) -> PostgresClient.Configuration.TLS {
            try configuration().map(PostgresClient.Configuration.TLS.require) ?? .disable
        }

        /// NIOSSL's configuration for this mode; `nil` when disabled.
        func configuration() throws(PostgreSQL.Error) -> TLSConfiguration? {
            switch mode {
            case .disabled:
                return nil
            case .required:
                var configuration = TLSConfiguration.makeClientConfiguration()
                configuration.certificateVerification = .none
                return configuration
            case .verified:
                var configuration = TLSConfiguration.makeClientConfiguration()
                configuration.certificateVerification = .fullVerification
                if !rootCertificates.isEmpty {
                    var certificates: [NIOSSLCertificate] = []
                    for root in rootCertificates {
                        certificates += try root.certificates()
                    }
                    configuration.additionalTrustRoots = [.certificates(certificates)]
                }
                return configuration
            }
        }
    }

    extension PostgreSQL.Configuration.TLS.Certificate {
        func certificates() throws(PostgreSQL.Error) -> [NIOSSLCertificate] {
            let certificates: [NIOSSLCertificate]
            do {
                switch self {
                case .pem(let text): certificates = try NIOSSLCertificate.fromPEMBytes(Array(text.utf8))
                case .file(let path): certificates = try NIOSSLCertificate.fromPEMFile(path)
                }
            } catch {
                throw PostgreSQL.Error(kind: .tls, message: "root certificate \(self) unreadable: \(error)")
            }
            guard !certificates.isEmpty else {
                throw PostgreSQL.Error(kind: .tls, message: "root certificate \(self) holds no certificate")
            }
            return certificates
        }
    }
#endif
