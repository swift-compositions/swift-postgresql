internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public enum Math {}
}

extension PostgreSQL.Math {
    public static func pi() -> some QueryExpression<Double> {
        SQLQueryExpression("pi()", as: Double.self)
    }

    public static func random() -> some QueryExpression<Double> {
        SQLQueryExpression("random()", as: Double.self)
    }

    public static func random(in range: ClosedRange<Int>) -> some QueryExpression<Int> {
        SQLQueryExpression("random(\(bind: range.lowerBound), \(bind: range.upperBound))", as: Int.self)
    }

    public static func random(in range: ClosedRange<Double>) -> some QueryExpression<Double> {
        SQLQueryExpression(
            "random(CAST(\(bind: range.lowerBound) AS NUMERIC), CAST(\(bind: range.upperBound) AS NUMERIC))",
            as: Double.self
        )
    }

    public static func randomNormal(mean: Double = 0, standardDeviation: Double = 1) -> some QueryExpression<Double> {
        SQLQueryExpression("random_normal(\(bind: mean), \(bind: standardDeviation))", as: Double.self)
    }

    public static func setseed(_ seed: some QueryExpression<Double>) -> some QueryExpression<Void> {
        SQLQueryExpression("setseed(\(seed))", as: Void.self)
    }
}
