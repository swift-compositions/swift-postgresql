public import PostgreSQL_SQL

extension PostgreSQL.Configuration {
    /// Why a URL or an environment gave no configuration.
    public enum Error: Swift.Error, Hashable, Sendable, CustomStringConvertible {
        /// The environment has none of the variables named.
        case missing(variable: String)

        /// A port that is not a number from 1 to 65535.
        case invalidPort(String)

        /// A URL whose `part` is wrong, with what was found there.
        case invalidURL(Part, String)

        public var description: String {
            switch self {
            case .missing(let variable): "no \(variable) in the environment"
            case .invalidPort(let port): "\(port) is not a port"
            case .invalidURL(let part, let found): "the URL's \(part) is wrong: \(found)"
            }
        }
    }
}

extension PostgreSQL.Configuration.Error {
    /// A part of a `postgres://` URL.
    public enum Part: String, Hashable, Sendable, CaseIterable {
        case scheme
        case user
        case password
        case host
        case port
        case database
        case sslmode
        case sslrootcert
    }
}
