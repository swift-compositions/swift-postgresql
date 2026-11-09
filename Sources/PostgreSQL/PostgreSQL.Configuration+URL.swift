public import PostgreSQL_SQL

extension PostgreSQL.Configuration {
    /// The configuration a `postgres://` or `postgresql://` URL names, as managed hosts hand them out:
    /// `postgres://user:password@host:port/database?sslmode=verify-full&sslrootcert=/path/to/root.pem`.
    ///
    /// The user, password and database are percent-decoded. The port defaults to 5432 and the database to the user.
    /// `sslmode` is `disable` (the default), `require` or `verify-full`; `sslrootcert` names a PEM file of extra roots
    /// for `verify-full`, or `system` for the system's alone. Other query parameters are ignored. The pool size and
    /// timeouts take their defaults.
    ///
    /// - Throws: ``Error/invalidURL(_:_:)`` naming the part that is wrong.
    public init(url: String) throws(Error) {
        guard let schemeEnd = url.firstRange(of: "://") else { throw .invalidURL(.scheme, url) }
        let scheme = String(url[..<schemeEnd.lowerBound])
        guard scheme == "postgres" || scheme == "postgresql" else { throw .invalidURL(.scheme, scheme) }

        var rest = url[schemeEnd.upperBound...]
        var query = Substring("")
        if let mark = rest.firstIndex(of: "?") {
            query = rest[rest.index(after: mark)...]
            rest = rest[..<mark]
        }
        var path = Substring("")
        if let slash = rest.firstIndex(of: "/") {
            path = rest[rest.index(after: slash)...]
            rest = rest[..<slash]
        }

        var authority = rest
        var user = ""
        var password: String?
        if let at = authority.lastIndex(of: "@") {
            let userInfo = authority[..<at]
            authority = authority[authority.index(after: at)...]
            if let colon = userInfo.firstIndex(of: ":") {
                user = try Self.decoded(userInfo[..<colon], .user)
                password = try Self.decoded(userInfo[userInfo.index(after: colon)...], .password)
            } else {
                user = try Self.decoded(userInfo, .user)
            }
        }
        guard !user.isEmpty else { throw .invalidURL(.user, "no user") }

        var host: Substring
        var port: Substring?
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { throw .invalidURL(.host, String(authority)) }
            host = authority[authority.index(after: authority.startIndex)..<close]
            let after = authority[authority.index(after: close)...]
            if !after.isEmpty {
                guard after.hasPrefix(":") else { throw .invalidURL(.host, String(authority)) }
                port = after.dropFirst()
            }
        } else if let colon = authority.lastIndex(of: ":") {
            host = authority[..<colon]
            port = authority[authority.index(after: colon)...]
        } else {
            host = authority
        }
        guard !host.isEmpty else { throw .invalidURL(.host, "no host") }

        var number = 5432
        if let port {
            guard let parsed = Int(port), (1...65535).contains(parsed) else { throw .invalidURL(.port, String(port)) }
            number = parsed
        }

        let database = path.isEmpty ? user : try Self.decoded(path, .database)

        var tls = TLS.disabled
        var roots: [TLS.Certificate] = []
        for parameter in query.split(separator: "&") {
            let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(pair[0])
            let value = pair.count > 1 ? pair[1] : ""
            switch name {
            case "sslmode":
                tls.mode = try Self.mode(try Self.decoded(value, .sslmode))
            case "sslrootcert":
                let file = try Self.decoded(value, .sslrootcert)
                guard !file.isEmpty else { throw .invalidURL(.sslrootcert, "no file") }
                if file != "system" { roots.append(.file(file)) }
            default:
                continue
            }
        }
        tls.rootCertificates = roots

        self.init(host: String(host), port: number, user: user, password: password, database: database, tls: tls)
    }

    /// The TLS mode an `sslmode` value names.
    static func mode(_ value: String) throws(Error) -> TLS.Mode {
        switch value {
        case "disable": .disabled
        case "require": .required
        case "verify-full": .verified
        default: throw .invalidURL(.sslmode, value)
        }
    }

    /// `text` with its `%XX` escapes decoded, as UTF-8.
    static func decoded(_ text: Substring, _ part: Error.Part) throws(Error) -> String {
        guard text.contains("%") else { return String(text) }
        var bytes: [UInt8] = []
        var index = text.utf8.startIndex
        let utf8 = text.utf8
        while index < utf8.endIndex {
            let byte = utf8[index]
            if byte == UInt8(ascii: "%") {
                let first = utf8.index(after: index)
                guard first < utf8.endIndex, utf8.index(after: first) < utf8.endIndex,
                    let high = Self.hex(utf8[first]), let low = Self.hex(utf8[utf8.index(after: first)])
                else { throw .invalidURL(part, String(text)) }
                bytes.append(high << 4 | low)
                index = utf8.index(first, offsetBy: 2)
            } else {
                bytes.append(byte)
                index = utf8.index(after: index)
            }
        }
        guard let decoded = String(validating: bytes, as: UTF8.self) else { throw .invalidURL(part, String(text)) }
        return decoded
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        default: nil
        }
    }
}
