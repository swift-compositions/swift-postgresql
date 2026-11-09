import ISO_9075_Foundation
import PostgreSQL
import SQL
import SQL_Macros
import Testing

@Suite struct `Common table expressions` {
    @Test func `a materialized expression renders its keyword`() throws {
        let rendering = try PostgreSQL().render(
            With {
                WindowFixtures.Score.where { $0.points > 10 }.select { CommonTableExpressionFixtures.HighScore.Columns(id: $0.id) }.materialized()
            } query: {
                CommonTableExpressionFixtures.HighScore.all
            }
            .query
        )
        #expect(rendering.sql.hasPrefix(#"WITH "high_scores" AS MATERIALIZED ("#))
        #expect(rendering.values == [ISO_9075.Value.int(10)])
    }

    @Test func `a not materialized expression renders its keyword`() throws {
        let rendering = try PostgreSQL().render(
            With {
                WindowFixtures.Score.where { $0.points > 10 }.select { CommonTableExpressionFixtures.HighScore.Columns(id: $0.id) }.materialized(.notMaterialized)
            } query: {
                CommonTableExpressionFixtures.HighScore.all
            }
            .query
        )
        #expect(rendering.sql.hasPrefix(#"WITH "high_scores" AS NOT MATERIALIZED ("#))
    }

    @Test func `a plain expression has no materialization keyword`() throws {
        let rendering = try PostgreSQL().render(
            With {
                WindowFixtures.Score.where { $0.points > 10 }.select { CommonTableExpressionFixtures.HighScore.Columns(id: $0.id) }
            } query: {
                CommonTableExpressionFixtures.HighScore.all
            }
            .query
        )
        #expect(rendering.sql.hasPrefix(#"WITH "high_scores" AS ("#))
    }
}

enum CommonTableExpressionFixtures {
    @Table("high_scores")
    struct HighScore {
        let id: Int
    }
}
