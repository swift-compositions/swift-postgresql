import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing
import Time

@Suite struct `Date and time functions` {
    let timestamp = DateTimeFixtures.Event.columns.timestamp

    @Test(
        arguments: [
            (.year, "YEAR"),
            (.month, "MONTH"),
            (.day, "DAY"),
            (.hour, "HOUR"),
            (.minute, "MINUTE"),
            (.dow, "DOW"),
            (.doy, "DOY"),
        ] as [(PostgreSQL.DateTime.Field<Int>, String)]
    )
    func `extract renders integer fields`(field: PostgreSQL.DateTime.Field<Int>, name: String) {
        #expect(
            PostgreSQL().render(timestamp.extract(field).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"EXTRACT(\#(name) FROM "events"."timestamp")"#,
                    values: []
                )
        )
    }

    @Test func `extract types epoch and second as Double`() {
        let epoch: some QueryExpression<Double> = timestamp.extract(.epoch)
        let second: some QueryExpression<Double> = timestamp.extract(.second)
        #expect(PostgreSQL().render(epoch.queryFragment).sql == #"EXTRACT(EPOCH FROM "events"."timestamp")"#)
        #expect(PostgreSQL().render(second.queryFragment).sql == #"EXTRACT(SECOND FROM "events"."timestamp")"#)
    }

    @Test func `extract compares against a bound value`() {
        #expect(
            PostgreSQL().render(timestamp.extract(.year).eq(2024).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"(EXTRACT(YEAR FROM "events"."timestamp")) = ($1)"#,
                    values: [.int(2024)]
                )
        )
    }

    @Test(arguments: PostgreSQL.DateTime.Precision.allCases)
    func `date_trunc inlines the precision`(precision: PostgreSQL.DateTime.Precision) {
        #expect(
            PostgreSQL().render(timestamp.dateTrunc(precision).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"DATE_TRUNC('\#(precision.rawValue)', "events"."timestamp")"#,
                    values: []
                )
        )
    }

    @Test func `now renders the function call`() {
        #expect(PostgreSQL().render(PostgreSQL.DateTime.now().queryFragment).sql == "now()")
        #expect(PostgreSQL().render(PostgreSQL.DateTime.now().dateTrunc(.hour).queryFragment).sql == "DATE_TRUNC('hour', now())")
    }

    @Test func `extract filters a select`() {
        let sql = PostgreSQL().render(DateTimeFixtures.Event.where { $0.timestamp.extract(.dow).eq(0) }.query).sql
        #expect(sql.contains(#"(EXTRACT(DOW FROM "events"."timestamp")) = ($1)"#))
    }
}
