import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Aggregate array_agg` {
    @Test func `array_agg aggregates the expression`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Customer.columns.name.arrayAgg().queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"array_agg("customers"."name")"#, values: []))
    }

    @Test func `distinct and order render inside the call`() {
        let name = AggregateFixtures.Customer.columns.name
        let rendering = PostgreSQL().render(name.arrayAgg(distinct: true, order: name.desc()).queryFragment)
        #expect(rendering.sql == #"array_agg(DISTINCT "customers"."name" ORDER BY "customers"."name" DESC)"#)
    }

    @Test func `a filter renders after the call`() {
        let columns = AggregateFixtures.Purchase.columns
        let rendering = PostgreSQL().render(columns.customerID.arrayAgg(filter: columns.isPaid).queryFragment)
        #expect(rendering.sql == #"array_agg("purchases"."customerID") FILTER (WHERE "purchases"."isPaid")"#)
    }

    @Test func `a table selects the aggregate`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Customer.arrayAgg { $0.name }.query)
        #expect(rendering.sql == "SELECT array_agg(\"customers\".\"name\")\nFROM \"customers\"")
        #expect(rendering.values == [])
    }

    @Test func `a table selects the filtered aggregate`() {
        let rendering = PostgreSQL().render(
            AggregateFixtures.Purchase.arrayAgg(of: { $0.customerID }, filter: { $0.isPaid }).query
        )
        #expect(rendering.sql.hasPrefix(#"SELECT array_agg("purchases"."customerID") FILTER (WHERE "purchases"."isPaid")"#))
    }

    @Test func `a where clause selects the aggregate`() {
        let rendering = PostgreSQL().render(
            AggregateFixtures.Purchase.where { $0.isPaid }.arrayAgg { $0.customerID }.query
        )
        #expect(rendering.sql.hasPrefix(#"SELECT array_agg("purchases"."customerID")"#))
        #expect(rendering.sql.contains(#"FROM "purchases""#))
        #expect(rendering.sql.contains("WHERE"))
    }
}

@Suite struct `Aggregate string_agg` {
    @Test func `string_agg binds the separator`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Customer.columns.name.stringAgg(", ").queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"string_agg("customers"."name", $1)"#, values: [.text(", ")]))
    }

    @Test func `the separator defaults to a comma`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Customer.columns.name.stringAgg().queryFragment)
        #expect(rendering.values == [.text(",")])
    }

    @Test func `distinct and order render inside the call`() {
        let name = AggregateFixtures.Customer.columns.name
        let rendering = PostgreSQL().render(name.stringAgg(";", distinct: true, order: name.asc()).queryFragment)
        #expect(rendering.sql == #"string_agg(DISTINCT "customers"."name", $1 ORDER BY "customers"."name" ASC)"#)
    }

    @Test func `a non-text expression is cast to text`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Customer.columns.id.stringAgg().queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"string_agg(CAST("customers"."id" AS TEXT), $1)"#,
                    values: [.text(",")]
                )
        )
    }
}

@Suite struct `Aggregate statistics` {
    @Test func `each statistic renders its function`() {
        let amount = AggregateFixtures.Purchase.columns.amount
        #expect(PostgreSQL().render(amount.stddev().queryFragment).sql == #"stddev("purchases"."amount")"#)
        #expect(PostgreSQL().render(amount.stddevPop().queryFragment).sql == #"stddev_pop("purchases"."amount")"#)
        #expect(PostgreSQL().render(amount.stddevSamp().queryFragment).sql == #"stddev_samp("purchases"."amount")"#)
        #expect(PostgreSQL().render(amount.variance().queryFragment).sql == #"variance("purchases"."amount")"#)
        #expect(PostgreSQL().render(amount.varPop().queryFragment).sql == #"var_pop("purchases"."amount")"#)
        #expect(PostgreSQL().render(amount.varSamp().queryFragment).sql == #"var_samp("purchases"."amount")"#)
    }

    @Test func `an optional numeric column aggregates`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Purchase.columns.discount.stddev().queryFragment)
        #expect(rendering.sql == #"stddev("purchases"."discount")"#)
    }

    @Test func `a filter renders after the call`() {
        let columns = AggregateFixtures.Purchase.columns
        let rendering = PostgreSQL().render(columns.amount.variance(filter: columns.isPaid).queryFragment)
        #expect(rendering.sql == #"variance("purchases"."amount") FILTER (WHERE "purchases"."isPaid")"#)
    }

    @Test func `a table selects the statistic`() {
        let rendering = PostgreSQL().render(AggregateFixtures.Purchase.stddev { $0.amount }.query)
        #expect(rendering.sql == "SELECT stddev(\"purchases\".\"amount\")\nFROM \"purchases\"")
    }

    @Test func `a table selects the filtered statistic`() {
        let rendering = PostgreSQL().render(
            AggregateFixtures.Purchase.variance(of: { $0.amount }, filter: { $0.isPaid }).query
        )
        #expect(rendering.sql.hasPrefix(#"SELECT variance("purchases"."amount") FILTER (WHERE "purchases"."isPaid")"#))
    }

    @Test func `a where clause selects the statistic`() {
        let rendering = PostgreSQL().render(
            AggregateFixtures.Purchase.where { $0.isPaid }.stddev(of: { $0.amount }, filter: { $0.isPaid }).query
        )
        #expect(rendering.sql.hasPrefix(#"SELECT stddev("purchases"."amount") FILTER (WHERE "purchases"."isPaid")"#))
        #expect(rendering.sql.contains("WHERE"))
    }
}

@Suite struct `Aggregate ordered sets` {
    let purchase = AggregateFixtures.Purchase.columns

    @Test func `a continuous percentile binds its fraction and orders within the group`() {
        let rendering = PostgreSQL().render(purchase.amount.percentileCont(0.5).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"percentile_cont($1) WITHIN GROUP (ORDER BY "purchases"."amount")"#,
                    values: [.double(0.5)]
                )
        )
    }

    @Test func `a discrete percentile keeps the value type`() {
        let rendering = PostgreSQL().render(purchase.customerID.percentileDisc(0.9, filter: purchase.isPaid).queryFragment)
        #expect(rendering.sql == #"percentile_disc($1) WITHIN GROUP (ORDER BY "purchases"."customerID") FILTER (WHERE "purchases"."isPaid")"#)
    }

    @Test func `mode takes no arguments`() {
        let rendering = PostgreSQL().render(purchase.customerID.mode().queryFragment)
        #expect(rendering.sql == #"mode() WITHIN GROUP (ORDER BY "purchases"."customerID")"#)
    }
}

@Suite struct `Aggregate booleans and correlations` {
    let purchase = AggregateFixtures.Purchase.columns

    @Test func `boolean aggregates render their names`() {
        #expect(PostgreSQL().render(purchase.isPaid.boolAnd().queryFragment).sql == #"bool_and("purchases"."isPaid")"#)
        #expect(PostgreSQL().render(purchase.isPaid.boolOr().queryFragment).sql == #"bool_or("purchases"."isPaid")"#)
    }

    @Test func `two-variable statistics take both expressions`() {
        #expect(
            PostgreSQL().render(purchase.amount.corr(purchase.discount).queryFragment).sql
                == #"corr("purchases"."amount", "purchases"."discount")"#
        )
        #expect(
            PostgreSQL().render(purchase.amount.covarSamp(purchase.customerID).queryFragment).sql
                == #"covar_samp("purchases"."amount", "purchases"."customerID")"#
        )
        #expect(
            PostgreSQL().render(purchase.amount.regrSlope(purchase.discount).queryFragment).sql
                == #"regr_slope("purchases"."amount", "purchases"."discount")"#
        )
    }
}
