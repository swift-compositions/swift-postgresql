import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Math functions` {
    let measurement = MathFixtures.Measurement.columns
    let number = MathFixtures.Number.columns

    @Test func `constants and randomness take no arguments`() {
        #expect(PostgreSQL().render(PostgreSQL.Math.pi().queryFragment).sql == "pi()")
        #expect(PostgreSQL().render(PostgreSQL.Math.random().queryFragment).sql == "random()")
        #expect(
            PostgreSQL().render(PostgreSQL.Math.setseed(0.5).queryFragment)
                == ISO_9075.Rendering(
                    sql: "setseed($1)",
                    values: [.double(0.5)]
                )
        )
    }

    @Test func `rounding functions wrap the expression`() {
        #expect(PostgreSQL().render(measurement.value.ceil().queryFragment).sql == #"ceil("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.ceiling().queryFragment).sql == #"ceiling("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.floor().queryFragment).sql == #"floor("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.trunc().queryFragment).sql == #"trunc("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.sign().queryFragment).sql == #"sign("measurements"."value")"#)
    }

    @Test func `rounding goes through numeric and returns double precision`() {
        #expect(
            PostgreSQL().render(measurement.value.round(2).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"CAST(round(CAST("measurements"."value" AS NUMERIC), CAST($1 AS INTEGER)) AS DOUBLE PRECISION)"#,
                    values: [.int(2)]
                )
        )
        #expect(
            PostgreSQL().render(measurement.value.round().queryFragment).sql
                == #"CAST(round(CAST("measurements"."value" AS NUMERIC)) AS DOUBLE PRECISION)"#
        )
    }

    @Test func `an unbounded limit is ALL`() {
        #expect(PostgreSQL().render(MathFixtures.Measurement.offset(5).select(\.value).query).sql.hasSuffix("LIMIT ALL OFFSET $1"))
    }

    @Test func `truncation to decimal places goes through numeric`() {
        let rendering = PostgreSQL().render(measurement.value.trunc(decimalPlaces: 2).queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"trunc(CAST("measurements"."value" AS NUMERIC), 2)"#, values: []))
    }

    @Test func `integer division binds a value divisor`() {
        let rendering = PostgreSQL().render(number.value.div(10).queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"div("numbers"."value", $1)"#, values: [.int(10)]))
    }

    @Test func `number theory functions take two expressions`() {
        #expect(
            PostgreSQL().render(number.value.gcd(number.divisor).queryFragment).sql
                == #"gcd("numbers"."value", "numbers"."divisor")"#
        )
        #expect(
            PostgreSQL().render(number.value.lcm(number.divisor).queryFragment).sql
                == #"lcm("numbers"."value", "numbers"."divisor")"#
        )
        #expect(PostgreSQL().render(number.value.factorial().queryFragment).sql == #"factorial("numbers"."value")"#)
    }

    @Test func `exponential functions render their names`() {
        #expect(
            PostgreSQL().render(measurement.value.power(2.0).queryFragment)
                == ISO_9075.Rendering(
                    sql: #"power("measurements"."value", $1)"#,
                    values: [.double(2)]
                )
        )
        #expect(PostgreSQL().render(measurement.value.sqrt().queryFragment).sql == #"sqrt("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.cbrt().queryFragment).sql == #"cbrt("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.exp().queryFragment).sql == #"exp("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.ln().queryFragment).sql == #"ln("measurements"."value")"#)
        #expect(PostgreSQL().render(measurement.value.log10().queryFragment).sql == #"log10("measurements"."value")"#)
    }

    @Test func `a logarithm with a base goes through numeric`() {
        let rendering = PostgreSQL().render(measurement.value.log(base: 2.0).queryFragment)
        #expect(rendering == ISO_9075.Rendering(sql: #"log(CAST($1 AS NUMERIC), CAST("measurements"."value" AS NUMERIC))"#, values: [.double(2)]))
    }

    @Test func `trigonometric functions render their names`() {
        #expect(PostgreSQL().render(measurement.angle.sin().queryFragment).sql == #"sin("measurements"."angle")"#)
        #expect(PostgreSQL().render(measurement.angle.acosh().queryFragment).sql == #"acosh("measurements"."angle")"#)
        #expect(PostgreSQL().render(measurement.angle.degrees().queryFragment).sql == #"degrees("measurements"."angle")"#)
        #expect(
            PostgreSQL().render(measurement.angle.atan2(measurement.value).queryFragment).sql
                == #"atan2("measurements"."angle", "measurements"."value")"#
        )
    }

    @Test func `numeric-only functions cast a double to numeric`() {
        #expect(
            PostgreSQL().render(measurement.value.div(measurement.angle).queryFragment).sql
                == #"div(CAST("measurements"."value" AS NUMERIC), CAST("measurements"."angle" AS NUMERIC))"#
        )
        #expect(
            PostgreSQL().render(measurement.value.mod(measurement.angle).queryFragment).sql
                == #"mod(CAST("measurements"."value" AS NUMERIC), CAST("measurements"."angle" AS NUMERIC))"#
        )
        #expect(
            PostgreSQL().render(measurement.value.minScale().queryFragment).sql
                == #"min_scale(CAST("measurements"."value" AS NUMERIC))"#
        )
        #expect(
            PostgreSQL().render(measurement.value.trimScale().queryFragment).sql
                == #"trim_scale(CAST("measurements"."value" AS NUMERIC))"#
        )
    }

    @Test func `integer division and modulo stay integral`() {
        #expect(
            PostgreSQL().render(number.value.mod(number.divisor).queryFragment).sql
                == #"mod("numbers"."value", "numbers"."divisor")"#
        )
    }

    @Test func `a width bucket inlines its bucket count`() {
        let rendering = PostgreSQL().render(measurement.value.widthBucket(from: 0.0, to: 10.0, buckets: 5).queryFragment)
        #expect(
            rendering
                == ISO_9075.Rendering(
                    sql: #"width_bucket("measurements"."value", $1, $2, 5)"#,
                    values: [.double(0), .double(10)]
                )
        )
    }

    @Test func `degree-based trigonometry renders its names`() {
        #expect(PostgreSQL().render(measurement.angle.sinDegrees().queryFragment).sql == #"sind("measurements"."angle")"#)
        #expect(
            PostgreSQL().render(measurement.angle.atan2Degrees(measurement.value).queryFragment).sql
                == #"atan2d("measurements"."angle", "measurements"."value")"#
        )
    }

    @Test func `random numbers in a range bind their bounds`() {
        #expect(
            PostgreSQL().render(PostgreSQL.Math.random(in: 1...6).queryFragment)
                == ISO_9075.Rendering(
                    sql: "random($1, $2)",
                    values: [.int(1), .int(6)]
                )
        )
        #expect(PostgreSQL().render(PostgreSQL.Math.randomNormal().queryFragment).sql == "random_normal($1, $2)")
    }
}
