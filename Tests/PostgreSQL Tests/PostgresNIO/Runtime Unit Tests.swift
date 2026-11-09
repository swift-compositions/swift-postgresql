#if PostgresNIO
    import Byte
    import ISO_9075_Call_Level_Interface
    import PostgreSQL
    import PostgreSQL_Test_Support
    import PostgresNIO
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
                ],
                tls: .disable
            )
            #expect(configuration.host == "localhost")
            #expect(configuration.port == 5432)
            #expect(configuration.database == "test_db")
            #expect(configuration.username == "postgres")
            #expect(configuration.password == "secret")
        }

        @Test func `falls back to the POSTGRES variables`() throws {
            let configuration = try PostgreSQL.Configuration(
                environment: ["POSTGRES_HOST": "db", "POSTGRES_PORT": "6543", "POSTGRES_DB": "app", "POSTGRES_USER": "app"],
                tls: .disable
            )
            #expect(configuration.host == "db")
            #expect(configuration.port == 6543)
            #expect(configuration.password == nil)
        }

        @Test func `names a missing variable`() throws {
            #expect(throws: PostgreSQL.Configuration.Error.missing(variable: "DATABASE_HOST or POSTGRES_HOST")) {
                try PostgreSQL.Configuration(
                    environment: ["DATABASE_PORT": "5432", "DATABASE_NAME": "db", "DATABASE_USER": "user"],
                    tls: .disable
                )
            }
        }

        @Test func `rejects a port that is not a number`() throws {
            #expect(throws: PostgreSQL.Configuration.Error.invalidPort("five")) {
                try PostgreSQL.Configuration(
                    environment: ["DATABASE_HOST": "h", "DATABASE_PORT": "five", "DATABASE_NAME": "db", "DATABASE_USER": "user"],
                    tls: .disable
                )
            }
        }

        @Test func `sizes the client pool`() {
            let client = PostgreSQL.Configuration.test(environment: [:]).client(connections: 2...20)
            #expect(client.options.minimumConnections == 2)
            #expect(client.options.maximumConnections == 20)
        }

        @Test func `defaults the test configuration to the local test database`() {
            let configuration = PostgreSQL.Configuration.test(environment: [:])
            #expect(configuration.host == "localhost")
            #expect(configuration.port == 5432)
            #expect(configuration.username == "coen")
            #expect(configuration.password == nil)
            #expect(configuration.database == "swift_postgresql_test")
        }

        @Test func `lets the environment override the test configuration`() {
            let configuration = PostgreSQL.Configuration.test(
                environment: ["POSTGRES_HOST": "ci", "POSTGRES_PORT": "15432", "POSTGRES_USER": "ci", "POSTGRES_PASSWORD": "pw", "POSTGRES_DB": "ci_db"]
            )
            #expect(configuration.host == "ci")
            #expect(configuration.port == 15432)
            #expect(configuration.username == "ci")
            #expect(configuration.password == "pw")
            #expect(configuration.database == "ci_db")
        }
    }

    @Suite struct `Queries from renderings` {
        @Test func `carry the SQL and one binding per value`() throws {
            let rendering = try PostgreSQL().render(
                "SELECT * FROM users WHERE id = \(ISO_9075.Value.int(42)) AND name = \(ISO_9075.Value.text("Alice"))"
            )
            let query = try PostgresQuery(rendering)
            #expect(query.sql == "SELECT * FROM users WHERE id = $1 AND name = $2")
            #expect(query.binds.count == 2)
        }

        @Test func `bind nulls and blobs`() throws {
            let rendering = try PostgreSQL().render(
                "UPDATE files SET content = \(ISO_9075.Value.blob([1, 2, 3].map(Byte.init(bitPattern:)))), owner = \(ISO_9075.Value.null)"
            )
            #expect(try PostgresQuery(rendering).binds.count == 2)
        }

        @Test func `bind a homogeneous array`() throws {
            let rendering = try PostgreSQL().render("SELECT \(ISO_9075.Value.array([.int(1), .int(2)], of: .int))")
            #expect(try PostgresQuery(rendering).binds.count == 1)
        }

        @Test func `reject a heterogeneous array with a typed error`() throws {
            let rendering = try PostgreSQL().render("SELECT \(ISO_9075.Value.array([.int(1), .text("a")], of: .int))")
            #expect(throws: ISO_9075.Error.self) {
                try PostgresQuery(rendering)
            }
        }

        @Test func `reject an invalid value with its failure`() {
            let failure = ISO_9075.Value.Failure("not encodable")
            #expect(throws: failure) {
                try PostgreSQL().render("SELECT \(ISO_9075.Value.invalid(failure))")
            }
            #expect(throws: ISO_9075.Error.binding(failure)) {
                try PostgresQuery(ISO_9075.Rendering(sql: "SELECT $1", values: [.invalid(failure)]))
            }
        }

        @Test func `reject a decimal that is not a number`() throws {
            let rendering = try PostgreSQL().render("SELECT \(ISO_9075.Value.decimal("1,5"))")
            #expect(throws: ISO_9075.Error.self) {
                try PostgresQuery(rendering)
            }
        }
    }
#endif
