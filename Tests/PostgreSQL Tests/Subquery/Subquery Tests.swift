import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Quantified subquery comparisons` {
    let product = SubqueryFixtures.Product.columns

    @Test func `equality against any row of a subquery`() {
        let subquery = SQLQueryExpression("SELECT id FROM featured", as: Int.self)
        let rendering = PostgreSQL().render(product.id.eq(.any(subquery)).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"("shop_products"."id") = ANY (SELECT id FROM featured)"#,
                    values: []
                )
        )
    }

    @Test func `each comparison renders its operator`() {
        let subquery = SQLQueryExpression("SELECT price FROM competitors", as: Double.self)
        #expect(
            PostgreSQL().render(product.price.neq(.any(subquery)).queryFragment).sql
                == #"("shop_products"."price") <> ANY (SELECT price FROM competitors)"#
        )
        #expect(
            PostgreSQL().render(product.price.lt(.all(subquery)).queryFragment).sql
                == #"("shop_products"."price") < ALL (SELECT price FROM competitors)"#
        )
        #expect(
            PostgreSQL().render(product.price.lte(.all(subquery)).queryFragment).sql
                == #"("shop_products"."price") <= ALL (SELECT price FROM competitors)"#
        )
        #expect(
            PostgreSQL().render(product.price.gt(.some(subquery)).queryFragment).sql
                == #"("shop_products"."price") > SOME (SELECT price FROM competitors)"#
        )
        #expect(
            PostgreSQL().render(product.price.gte(.some(subquery)).queryFragment).sql
                == #"("shop_products"."price") >= SOME (SELECT price FROM competitors)"#
        )
    }

    @Test func `a select statement renders as the subquery`() {
        let rendering = PostgreSQL().render(
            product.id.eq(.any(SubqueryFixtures.Featured.select(\.productID))).queryFragment
        )
        #expect(rendering.sql == "(\"shop_products\".\"id\") = ANY (SELECT \"featured_products\".\"productID\"\nFROM \"featured_products\")")
    }

    @Test func `an array operand is bound`() {
        let rendering = PostgreSQL().render(
            product.id.eq(.any(PostgreSQL.Array<Int>([1, 2]))).queryFragment
        )
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"("shop_products"."id") = ANY ($1)"#,
                    values: [.array([.int(1), .int(2)], of: .int)]
                )
        )
    }

    @Test func `a quantified comparison filters a query`() {
        let subquery = SQLQueryExpression("SELECT id FROM banned", as: Int.self)
        let rendering = PostgreSQL().render(
            SubqueryFixtures.Product.where { $0.id.neq(.all(subquery)) }.query
        )
        #expect(rendering.sql.contains(#"("shop_products"."id") <> ALL (SELECT id FROM banned)"#))
    }
}
