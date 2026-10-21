import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Binary string functions` {
    @Test func `encode inlines the encoding`() {
        #expect(
            PostgreSQL().render(BinaryFixtures.Attachment.columns.content.encode(.hex).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"encode("attachments"."content", 'hex')"#,
                    values: []
                )
        )
    }

    @Test func `decode inlines the encoding`() {
        #expect(PostgreSQL().render(BinaryFixtures.Attachment.columns.digest.decode(.base64).queryFragment).sql == #"decode("attachments"."digest", 'base64')"#)
    }
}
