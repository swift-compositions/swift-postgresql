import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Comparison functions` {
    let item = ComparisonFixtures.Item.columns

    @Test func `greatest renders every argument`() {
        let rendering = PostgreSQL().render(
            PostgreSQL.Comparison.greatest(item.price, item.comparePrice).queryFragment
        )
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"greatest("price_items"."price", "price_items"."comparePrice")"#,
                    values: []
                )
        )
    }

    @Test func `least binds a value argument`() {
        let rendering = PostgreSQL().render(
            PostgreSQL.Comparison.least(item.price, 100.0, item.comparePrice).queryFragment
        )
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"least("price_items"."price", $1, "price_items"."comparePrice")"#,
                    values: [.double(100.0)]
                )
        )
    }

    @Test func `null counting accepts mixed types`() {
        #expect(
            PostgreSQL().render(PostgreSQL.Comparison.numNulls(item.note, item.code).queryFragment).sql
                == #"num_nulls("price_items"."note", "price_items"."code")"#
        )
        #expect(
            PostgreSQL().render(PostgreSQL.Comparison.numNonNulls(item.note, item.code, item.price).queryFragment).sql
                == #"num_nonnulls("price_items"."note", "price_items"."code", "price_items"."price")"#
        )
    }
}
