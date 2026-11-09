import PostgreSQL
import PostgreSQL_Test_Support
import Testing

@Suite struct `Configuration from an environment` {
    @Test func `reads the DATABASE variables`() throws {
        let configuration = try PostgreSQL.Configuration(
            environment: [
                "DATABASE_HOST": "localhost",
                "DATABASE_PORT": "5432",
                "DATABASE_NAME": "test_db",
                "DATABASE_USER": "postgres",
                "DATABASE_PASSWORD": "secret",
            ]
        )
        #expect(
            configuration
                == PostgreSQL.Configuration(host: "localhost", user: "postgres", password: "secret", database: "test_db")
        )
    }

    @Test func `falls back to the POSTGRES variables`() throws {
        let configuration = try PostgreSQL.Configuration(
            environment: ["POSTGRES_HOST": "db", "POSTGRES_PORT": "6543", "POSTGRES_DB": "app", "POSTGRES_USER": "app"]
        )
        #expect(configuration.host == "db")
        #expect(configuration.port == 6543)
        #expect(configuration.password == nil)
        #expect(configuration.tls == .disabled)
    }

    @Test func `reads DATABASE_URL before the variables`() throws {
        let configuration = try PostgreSQL.Configuration(
            environment: ["DATABASE_URL": "postgres://u:p@url-host/url_db", "DATABASE_HOST": "variable-host"]
        )
        #expect(configuration.host == "url-host")
        #expect(configuration.database == "url_db")
    }

    @Test func `reads TLS from the variables`() throws {
        let configuration = try PostgreSQL.Configuration(
            environment: [
                "DATABASE_HOST": "h", "DATABASE_PORT": "5432", "DATABASE_NAME": "db", "DATABASE_USER": "user",
                "DATABASE_SSLMODE": "verify-full", "DATABASE_SSLROOTCERT": "/etc/root.pem",
            ]
        )
        #expect(configuration.tls == .verified(rootCertificates: [.file("/etc/root.pem")]))
    }

    @Test func `names a missing variable`() {
        #expect(throws: PostgreSQL.Configuration.Error.missing(variable: "DATABASE_HOST or POSTGRES_HOST")) {
            try PostgreSQL.Configuration(environment: ["DATABASE_PORT": "5432", "DATABASE_NAME": "db", "DATABASE_USER": "user"])
        }
    }

    @Test func `rejects a port that is not a number`() {
        #expect(throws: PostgreSQL.Configuration.Error.invalidPort("five")) {
            try PostgreSQL.Configuration(
                environment: ["DATABASE_HOST": "h", "DATABASE_PORT": "five", "DATABASE_NAME": "db", "DATABASE_USER": "user"]
            )
        }
    }

    @Test func `defaults the test configuration to the local test database, as the current user`() {
        let configuration = PostgreSQL.Configuration.test(environment: ["USER": "maker"])
        #expect(configuration.host == "localhost")
        #expect(configuration.port == 5432)
        #expect(configuration.user == "maker")
        #expect(PostgreSQL.Configuration.test(environment: [:]).user == "postgres")
        #expect(configuration.password == nil)
        #expect(configuration.database == "swift_postgresql_test")
        #expect(configuration.tls == .disabled)
    }

    @Test func `lets the environment override the test configuration`() {
        let configuration = PostgreSQL.Configuration.test(
            environment: [
                "POSTGRES_HOST": "ci", "POSTGRES_PORT": "15432", "POSTGRES_USER": "ci", "POSTGRES_PASSWORD": "pw",
                "POSTGRES_DB": "ci_db", "POSTGRES_SSLMODE": "verify-full", "POSTGRES_SSLROOTCERT": "/ca.pem",
            ]
        )
        #expect(
            configuration
                == PostgreSQL.Configuration(
                    host: "ci",
                    port: 15432,
                    user: "ci",
                    password: "pw",
                    database: "ci_db",
                    tls: .verified(rootCertificates: [.file("/ca.pem")])
                )
        )
    }
}

@Suite struct `Configuration from a URL` {
    @Test func `reads every part`() throws {
        let configuration = try PostgreSQL.Configuration(url: "postgres://maker:s3cret@db.example.com:6543/directory")
        #expect(
            configuration
                == PostgreSQL.Configuration(
                    host: "db.example.com",
                    port: 6543,
                    user: "maker",
                    password: "s3cret",
                    database: "directory"
                )
        )
    }

    @Test func `takes either scheme`() throws {
        #expect(try PostgreSQL.Configuration(url: "postgresql://u@h/d").host == "h")
        #expect(try PostgreSQL.Configuration(url: "postgres://u@h/d").host == "h")
    }

    @Test func `defaults the port to 5432 and the database to the user`() throws {
        let configuration = try PostgreSQL.Configuration(url: "postgres://maker@host")
        #expect(configuration.port == 5432)
        #expect(configuration.database == "maker")
        #expect(configuration.password == nil)
    }

    @Test func `percent-decodes the user, password and database`() throws {
        let configuration = try PostgreSQL.Configuration(url: "postgres://us%40er:p%3Ass%2Fw%25rd%20%C3%A9@host/d%C3%A9b")
        #expect(configuration.user == "us@er")
        #expect(configuration.password == "p:ss/w%rd é")
        #expect(configuration.database == "déb")
    }

    @Test func `reads a bracketed IPv6 host`() throws {
        let configuration = try PostgreSQL.Configuration(url: "postgres://u@[::1]:5433/d")
        #expect(configuration.host == "::1")
        #expect(configuration.port == 5433)
    }

    @Test(arguments: [
        ("disable", PostgreSQL.Configuration.TLS.Mode.disabled),
        ("require", .required),
        ("verify-full", .verified),
    ])
    func `reads sslmode`(value: String, mode: PostgreSQL.Configuration.TLS.Mode) throws {
        #expect(try PostgreSQL.Configuration(url: "postgres://u@h/d?sslmode=\(value)").tls.mode == mode)
    }

    @Test func `reads sslrootcert and ignores other parameters`() throws {
        let configuration = try PostgreSQL.Configuration(
            url: "postgres://u@h/d?application_name=rule.law&sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Froot.pem"
        )
        #expect(configuration.tls == .verified(rootCertificates: [.file("/etc/ssl/root.pem")]))
        #expect(try PostgreSQL.Configuration(url: "postgres://u@h/d?sslmode=verify-full&sslrootcert=system").tls == .verified)
    }

    @Test(arguments: [
        ("mysql://u@h/d", PostgreSQL.Configuration.Error.invalidURL(.scheme, "mysql")),
        ("u@h/d", .invalidURL(.scheme, "u@h/d")),
        ("postgres://h/d", .invalidURL(.user, "no user")),
        ("postgres://u@/d", .invalidURL(.host, "no host")),
        ("postgres://u@h:0/d", .invalidURL(.port, "0")),
        ("postgres://u@h:65536/d", .invalidURL(.port, "65536")),
        ("postgres://u@h:port/d", .invalidURL(.port, "port")),
        ("postgres://u:%zz@h/d", .invalidURL(.password, "%zz")),
        ("postgres://u%2@h/d", .invalidURL(.user, "u%2")),
        ("postgres://u@h/d%ff", .invalidURL(.database, "d%ff")),
        ("postgres://u@[::1/d", .invalidURL(.host, "[::1")),
        ("postgres://u@h/d?sslmode=prefer", .invalidURL(.sslmode, "prefer")),
        ("postgres://u@h/d?sslrootcert=", .invalidURL(.sslrootcert, "no file")),
    ])
    func `names the part that is wrong`(url: String, error: PostgreSQL.Configuration.Error) {
        #expect(throws: error) { try PostgreSQL.Configuration(url: url) }
    }
}
