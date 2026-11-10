import ISO_9075_Foundation
import PostgreSQL
import Testing

@Suite struct `Binary large objects` {
    @Test func `PostgreSQL spells the binary large object type BYTEA`() throws {
        let fragment: ISO_9075.Fragment = "CREATE TABLE \(quote: "files") (\(quote: "bytes") \(ISO_9075.Keyword.binaryLargeObject))"
        #expect(try PostgreSQL().render(fragment).sql == #"CREATE TABLE "files" ("bytes" BYTEA)"#)
    }
}
