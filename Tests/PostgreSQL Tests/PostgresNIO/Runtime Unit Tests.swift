#if PostgresNIO
    import Byte
    import ISO_9075_Call_Level_Interface
    import PostgreSQL
    import PostgreSQL_Test_Support
    import PostgresNIO
    import Testing

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
