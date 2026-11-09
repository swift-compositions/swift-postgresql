public import PostgreSQL_SQL
#if PostgresNIO
    package import NIOSSL
    package import PostgresNIO

    extension PostgreSQL.Configuration {
        /// The engine's configuration for this one. Reads the root certificate files, so it throws
        /// ``PostgreSQL/Error/Kind/tls`` for one that can't be read or holds no certificate.
        package func client() throws(PostgreSQL.Error) -> PostgresClient.Configuration {
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

    extension PostgreSQL.Configuration.TLS {
        package func engine() throws(PostgreSQL.Error) -> PostgresClient.Configuration.TLS {
            switch mode {
            case .disabled:
                return .disable
            case .required:
                var configuration = TLSConfiguration.makeClientConfiguration()
                configuration.certificateVerification = .none
                return .require(configuration)
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
                return .require(configuration)
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
