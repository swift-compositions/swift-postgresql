import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing
import Time

@Suite struct `Formatting functions` {
    let columns = FormattingFixtures.Invoice.columns

    @Test func `to_char binds the format for timestamps and numbers`() {
        #expect(
            PostgreSQL().render(columns.issuedAt.toChar("YYYY-MM-DD").queryFragment)
                == ISO_9075.Rendering(
                    sql: #"to_char("invoices"."issuedAt", $1)"#,
                    values: [.text("YYYY-MM-DD")]
                )
        )
        #expect(PostgreSQL().render(columns.amount.toChar("999D99").queryFragment).sql == #"to_char("invoices"."amount", $1)"#)
        #expect(PostgreSQL().render(columns.id.toChar("0000").queryFragment).sql == #"to_char("invoices"."id", $1)"#)
    }

    @Test func `parsing functions bind the format`() {
        let date: some QueryExpression<Time.Instant> = columns.reference.toDate(format: "YYYY-MM-DD")
        #expect(
            PostgreSQL().render(date.queryFragment)
                == ISO_9075.Rendering(
                    sql: #"to_date("invoices"."reference", $1)"#,
                    values: [.text("YYYY-MM-DD")]
                )
        )
        #expect(PostgreSQL().render(columns.reference.toTimestamp(format: "YYYY").queryFragment).sql == #"to_timestamp("invoices"."reference", $1)"#)
        #expect(PostgreSQL().render(columns.reference.toNumber(format: "999").queryFragment).sql == #"to_number("invoices"."reference", $1)"#)
    }

    @Test func `to_timestamp converts epoch seconds`() {
        let timestamp: some QueryExpression<Time.Instant> = columns.amount.toTimestamp()
        #expect(PostgreSQL().render(timestamp.queryFragment).sql == #"to_timestamp("invoices"."amount")"#)
    }

    @Test func `age with and without a reference`() {
        #expect(PostgreSQL().render(columns.issuedAt.age().queryFragment).sql == #"age("invoices"."issuedAt")"#)
        #expect(PostgreSQL().render(columns.issuedAt.age(from: PostgreSQL.DateTime.now()).queryFragment).sql == #"age("invoices"."issuedAt", now())"#)
    }

    @Test func `justify functions`() {
        #expect(PostgreSQL().render(columns.reference.justifyDays().queryFragment).sql == #"justify_days("invoices"."reference")"#)
        #expect(PostgreSQL().render(columns.reference.justifyHours().queryFragment).sql == #"justify_hours("invoices"."reference")"#)
        #expect(PostgreSQL().render(columns.reference.justifyInterval().queryFragment).sql == #"justify_interval("invoices"."reference")"#)
    }
}
