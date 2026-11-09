public import PostgreSQL_SQL

extension PostgreSQL.Configuration {
    /// Whether a connection is encrypted, and what it checks of the server it reaches.
    public struct TLS: Sendable, Hashable {
        /// How much of the server's identity the connection checks.
        public enum Mode: Sendable, Hashable {
            /// No encryption. A server that requires TLS refuses the connection.
            case disabled

            /// Encrypted, but the server's certificate is not checked: protects against reading, not against a server
            /// that impersonates the real one. `sslmode=require` in a URL.
            case required

            /// Encrypted, with the server's certificate chain checked against the trusted roots and its name against
            /// ``PostgreSQL/Configuration/host``. `sslmode=verify-full` in a URL.
            case verified
        }

        public var mode: Mode

        /// Certificates trusted as roots besides the system's, for a server whose certificate a private authority
        /// signed. Only ``Mode/verified`` reads them.
        public var rootCertificates: [Certificate]

        public init(mode: Mode, rootCertificates: [Certificate] = []) {
            self.mode = mode
            self.rootCertificates = rootCertificates
        }

        public static let disabled = Self(mode: .disabled)

        public static let required = Self(mode: .required)

        public static let verified = Self(mode: .verified)

        /// Verified against the system's roots and `rootCertificates`.
        public static func verified(rootCertificates: [Certificate]) -> Self {
            Self(mode: .verified, rootCertificates: rootCertificates)
        }
    }
}

extension PostgreSQL.Configuration.TLS {
    /// One or more X.509 certificates in PEM form.
    public enum Certificate: Sendable, Hashable {
        /// PEM text: one or more `-----BEGIN CERTIFICATE-----` blocks.
        case pem(String)

        /// The path of a PEM file, read when the database is made.
        case file(String)
    }
}
