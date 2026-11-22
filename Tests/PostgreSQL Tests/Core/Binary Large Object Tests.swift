import ISO_9075_Foundation
import PostgreSQL
import Testing

extension PostgreSQL {
    @Suite struct Test {
        @Suite struct Unit {}
    }
}

extension PostgreSQL.Test.Unit {
    @Test func `PostgreSQL spells the binary large object type BYTEA`() throws {
        let fragment: ISO.`9075`.Fragment = "CREATE TABLE \(quote: "files") (\(quote: "bytes") \(ISO.`9075`.Keyword.binaryLargeObject))"
        #expect(try PostgreSQL().render(fragment).sql == #"CREATE TABLE "files" ("bytes" BYTEA)"#)
    }
}
