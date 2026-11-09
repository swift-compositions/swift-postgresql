import Byte
import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `JSONB aggregates` {
    @Test func `json and jsonb aggregates`() throws {
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.name.jsonAgg().queryFragment).sql
                == #"json_agg("users"."name")"#
        )
        #expect(
            try PostgreSQL().render(JSONBFixtures.User.columns.name.jsonbAgg().queryFragment).sql
                == #"jsonb_agg("users"."name")"#
        )
    }

    @Test func `jsonb aggregate with distinct and filter`() throws {
        #expect(
            try PostgreSQL().render(
                JSONBFixtures.Order.columns.id.jsonbAgg(distinct: true, filter: JSONBFixtures.Order.columns.isPaid)
                    .queryFragment
            ).sql == #"jsonb_agg(DISTINCT "orders"."id") FILTER (WHERE "orders"."isPaid")"#
        )
    }

    @Test func `jsonb aggregate with order`() throws {
        let sql = try PostgreSQL().render(
            JSONBFixtures.User.columns.name.jsonbAgg(order: JSONBFixtures.User.columns.name.desc()).queryFragment
        ).sql
        #expect(sql.hasPrefix(#"jsonb_agg("users"."name" ORDER BY "#))
        #expect(sql.hasSuffix(")"))
    }

    @Test func `jsonb aggregate of a calculated expression`() throws {
        #expect(
            try PostgreSQL().render((JSONBFixtures.Order.columns.amount * 2.0).jsonbAgg().queryFragment)
                == ISO_9075.Rendering(sql: #"jsonb_agg(("orders"."amount") * ($1))"#, values: [.double(2.0)])
        )
    }

    @Test func `table jsonb aggregate`() throws {
        let _: Select<[Byte]?, JSONBFixtures.Order, ()> = JSONBFixtures.Order.jsonbAgg { $0.id }
        let sql = try PostgreSQL().render(JSONBFixtures.Order.jsonbAgg { $0.id }.query).sql
        #expect(sql.contains(#"jsonb_agg("orders"."id")"#))
        #expect(sql.contains(#"FROM "orders""#))
    }

    @Test func `table jsonb aggregate with filter`() throws {
        let sql = try PostgreSQL().render(
            JSONBFixtures.Order.jsonbAgg(of: { $0.id }, filter: { $0.isPaid }).query
        ).sql
        #expect(sql.contains(#"jsonb_agg("orders"."id") FILTER (WHERE "orders"."isPaid")"#))
    }

    @Test func `where jsonb aggregate`() throws {
        let _: Select<[Byte]?, JSONBFixtures.Order, ()> = JSONBFixtures.Order.where { $0.isPaid }.jsonbAgg { $0.id }
        let sql = try PostgreSQL().render(JSONBFixtures.Order.where { $0.isPaid }.jsonbAgg { $0.id }.query).sql
        #expect(sql.contains(#"jsonb_agg("orders"."id")"#))
        #expect(sql.contains("WHERE"))
        #expect(sql.contains(#""orders"."isPaid""#))
    }

    @Test func `where jsonb aggregate with filter`() throws {
        let sql = try PostgreSQL().render(
            JSONBFixtures.Order.where { $0.amount.gt(100.0) }.jsonbAgg(of: { $0.id }, filter: { $0.isPaid }).query
        ).sql
        #expect(sql.contains(#"jsonb_agg("orders"."id") FILTER (WHERE "orders"."isPaid")"#))
        #expect(sql.contains("WHERE"))
    }
}
