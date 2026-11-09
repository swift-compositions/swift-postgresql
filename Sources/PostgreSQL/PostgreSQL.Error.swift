public import ISO_9075_Call_Level_Interface
public import PostgreSQL_SQL

extension PostgreSQL {
    /// A failure to reach the server, or one the server reported: what kind it is, its SQLSTATE code when the server
    /// gave one, its message, and the statement it was running.
    ///
    /// Every read, write and listen of ``PostgreSQL/Database`` throws this for what fails in the database rather than
    /// in the caller's own code, so a caller tells a unique violation from a lost connection by ``kind`` and
    /// ``code``, never by the engine's own error types.
    public struct Error: Swift.Error, Hashable, Sendable, CustomStringConvertible {
        /// What failed.
        public var kind: Kind

        /// The SQLSTATE code the server reported, such as ``Code/uniqueViolation``. `nil` for a failure on the
        /// client's side: a connection that could not be opened, a timeout, a cancelled task.
        public var code: Code?

        /// The server's message, or a description of what failed on the client's side.
        public var message: String

        /// The server's detail, when it gave one: for a unique violation, the key that already exists.
        public var detail: String?

        /// The statement that was running, when there was one.
        public var statement: String?

        public init(kind: Kind, code: Code? = nil, message: String, detail: String? = nil, statement: String? = nil) {
            self.kind = kind
            self.code = code
            self.message = message
            self.detail = detail
            self.statement = statement
        }

        public var description: String {
            var description = "PostgreSQL \(kind) error"
            if let code { description += " \(code.rawValue)" }
            description += ": \(message)"
            if let detail { description += " (\(detail))" }
            if let statement { description += " - while executing `\(statement)`" }
            return description
        }
    }
}

extension PostgreSQL.Error {
    /// What a ``PostgreSQL/Error`` is about.
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        /// The server ran the statement and refused it: a constraint, a syntax error, a serialization failure. The
        /// ``PostgreSQL/Error/code`` says which.
        case server

        /// No connection could be opened: the host is unknown, nothing listens on the port, or the server refuses
        /// connections.
        case connect

        /// The TLS handshake failed: the server offers no TLS, or its certificate is not trusted or not for its host.
        case tls

        /// The server refused the user or the password.
        case authentication

        /// A connection could not be opened, or none came free, in the configured time.
        case timeout

        /// The connection closed while it was in use: the server restarted, or the connection was terminated.
        case closed

        /// The task was cancelled.
        case cancelled

        /// A value could not be bound to a statement, or a row could not be decoded into the type asked for.
        case value
    }
}

extension PostgreSQL.Error {
    /// A SQLSTATE code (<https://www.postgresql.org/docs/current/errcodes-appendix.html>): five characters, of which
    /// the first two name the class.
    public struct Code: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The class: the code's first two characters, such as `23` for an integrity constraint violation.
        public var `class`: String { String(rawValue.prefix(2)) }

        public var description: String { rawValue }
    }
}

extension PostgreSQL.Error.Code {
    public static let uniqueViolation = Self(rawValue: "23505")
    public static let foreignKeyViolation = Self(rawValue: "23503")
    public static let notNullViolation = Self(rawValue: "23502")
    public static let checkViolation = Self(rawValue: "23514")
    public static let exclusionViolation = Self(rawValue: "23P01")
    public static let serializationFailure = Self(rawValue: "40001")
    public static let deadlockDetected = Self(rawValue: "40P01")
    public static let syntaxError = Self(rawValue: "42601")
    public static let undefinedTable = Self(rawValue: "42P01")
    public static let undefinedColumn = Self(rawValue: "42703")
    public static let duplicateTable = Self(rawValue: "42P07")
    public static let invalidPassword = Self(rawValue: "28P01")
    public static let invalidAuthorization = Self(rawValue: "28000")
    public static let invalidCatalogName = Self(rawValue: "3D000")
    public static let queryCanceled = Self(rawValue: "57014")
    public static let adminShutdown = Self(rawValue: "57P01")
    public static let crashShutdown = Self(rawValue: "57P02")
    public static let cannotConnectNow = Self(rawValue: "57P03")
    public static let tooManyConnections = Self(rawValue: "53300")
}

extension ISO_9075.Error {
    /// A ``PostgreSQL/Error`` as the call-level interface's error, for a contract that names no database: an
    /// execution error described by its kind, code, message and statement.
    public init(_ error: PostgreSQL.Error) {
        self = .execution(error.description)
    }
}

extension PostgreSQL.Error {
    /// A failure the call-level interface reported, as a ``PostgreSQL/Error``: a value that could not be bound or
    /// decoded is ``Kind/value``; any other keeps its description as a ``Kind/server`` error without a code.
    public init(_ error: ISO_9075.Error) {
        switch error {
        case .binding(let failure): self.init(kind: .value, message: "\(failure)")
        case .decoding(let reason): self.init(kind: .value, message: reason)
        case .connection(let reason): self.init(kind: .connect, message: reason)
        case .execution(let reason), .transaction(let reason): self.init(kind: .server, message: reason)
        }
    }
}
