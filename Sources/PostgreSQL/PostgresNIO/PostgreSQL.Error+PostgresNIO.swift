public import PostgreSQL_SQL
#if PostgresNIO
    internal import ISO_9075_Call_Level_Interface
    internal import NIOCore
    internal import NIOSSL
    package import PostgresNIO

    extension PostgreSQL.Error {
        /// The engine's error as a ``PostgreSQL/Error``.
        package init(_ error: PSQLError, statement: String? = nil) {
            let statement = statement ?? error.query.map(\.sql)
            if let info = error.serverInfo, let state = info[.sqlState] {
                let code = Code(rawValue: state)
                let kind: Kind =
                    switch code.class {
                    case "28": .authentication
                    case "57" where code != .queryCanceled && code != .cannotConnectNow: .closed
                    case "57" where code == .queryCanceled: .cancelled
                    case "57", "53", "08", "3D": .connect
                    default: .server
                    }
                self.init(
                    kind: kind,
                    code: code,
                    message: info[.message] ?? "\(error.code)",
                    detail: info[.detail],
                    statement: statement
                )
                return
            }
            let underlying = error.underlying.map { "\($0)" }
            let message = underlying.map { "\(error.code): \($0)" } ?? "\(error.code)"
            let kind: Kind =
                switch error.code {
                case .sslUnsupported, .failedToAddSSLHandler, .receivedUnencryptedDataAfterSSLRequest: .tls
                case .unsupportedAuthMechanism, .authMechanismRequiresPassword, .saslError: .authentication
                case .queryCancelled: .cancelled
                case .clientClosedConnection, .serverClosedConnection, .uncleanShutdown, .poolClosed: .closed
                case .connectionError: Self.kind(connecting: error.underlying)
                default: .server
                }
            self.init(kind: kind, message: message, statement: statement)
        }

        /// What kind of failure opening a connection met, by the error underneath.
        private static func kind(connecting underlying: (any Swift.Error)?) -> Kind {
            switch underlying {
            case is NIOSSLError, is BoringSSLError, is NIOSSLExtraError: .tls
            case let error as ChannelError:
                if case .connectTimeout = error { .timeout } else { .connect }
            case let error as PSQLError: PostgreSQL.Error(error).kind
            default: .connect
            }
        }

        /// Any error the engine, the call-level interface or the task can throw, as a ``PostgreSQL/Error``.
        package static func translated(_ error: any Swift.Error, statement: String? = nil) -> PostgreSQL.Error {
            switch error {
            case let error as PostgreSQL.Error: error
            case let error as PSQLError: PostgreSQL.Error(error, statement: statement)
            case let error as ISO_9075.Error: PostgreSQL.Error(error)
            case is CancellationError: PostgreSQL.Error(kind: .cancelled, message: "the task was cancelled", statement: statement)
            case is NIOSSLError, is BoringSSLError, is NIOSSLExtraError:
                PostgreSQL.Error(kind: .tls, message: "\(error)", statement: statement)
            default: PostgreSQL.Error(kind: .connect, message: "\(error)", statement: statement)
            }
        }
    }
#endif
