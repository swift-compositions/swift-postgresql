internal import ISO_9075_Foundation
public import SQL

extension QueryExpression where QueryValue: FloatingPoint & QueryBindable {
    public func ceil() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("ceil(\(self))", as: QueryValue.self)
    }

    public func ceiling() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("ceiling(\(self))", as: QueryValue.self)
    }

    public func floor() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("floor(\(self))", as: QueryValue.self)
    }

    public func trunc() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("trunc(\(self))", as: QueryValue.self)
    }

    public func trunc(decimalPlaces: Int) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("trunc(\(numeric), \(raw: decimalPlaces))", as: QueryValue.self)
    }

    public func sign() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("sign(\(self))", as: QueryValue.self)
    }

    public func div(_ divisor: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("div(\(numeric), CAST(\(divisor) AS NUMERIC))", as: QueryValue.self)
    }

    public func mod(_ divisor: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("mod(\(numeric), CAST(\(divisor) AS NUMERIC))", as: QueryValue.self)
    }
}

extension QueryExpression where QueryValue: BinaryInteger & QueryBindable {
    public func div(_ divisor: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("div(\(self), \(divisor))", as: QueryValue.self)
    }

    public func mod(_ divisor: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("mod(\(self), \(divisor))", as: QueryValue.self)
    }

    public func gcd(_ other: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("gcd(\(self), \(other))", as: QueryValue.self)
    }

    public func lcm(_ other: some QueryExpression<QueryValue>) -> some QueryExpression<QueryValue> {
        SQLQueryExpression("lcm(\(self), \(other))", as: QueryValue.self)
    }

    public func factorial() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("factorial(\(self))", as: QueryValue.self)
    }
}

extension QueryExpression where QueryValue: Numeric & QueryBindable {
    public func sqrt() -> some QueryExpression<Double> {
        SQLQueryExpression("sqrt(\(self))", as: Double.self)
    }

    public func cbrt() -> some QueryExpression<Double> {
        SQLQueryExpression("cbrt(\(self))", as: Double.self)
    }

    public func power(_ exponent: some QueryExpression<QueryValue>) -> some QueryExpression<Double> {
        SQLQueryExpression("power(\(self), \(exponent))", as: Double.self)
    }

    public func scale() -> some QueryExpression<Int> {
        SQLQueryExpression("scale(\(numeric))", as: Int.self)
    }

    public func minScale() -> some QueryExpression<Int> {
        SQLQueryExpression("min_scale(\(numeric))", as: Int.self)
    }

    public func trimScale() -> some QueryExpression<QueryValue> {
        SQLQueryExpression("trim_scale(\(numeric))", as: QueryValue.self)
    }

    public func widthBucket(
        from low: some QueryExpression<QueryValue>,
        to high: some QueryExpression<QueryValue>,
        buckets: Int
    ) -> some QueryExpression<Int> {
        precondition(buckets > 0, "width_bucket needs at least one bucket, got \(buckets)")
        return SQLQueryExpression("width_bucket(\(self), \(low), \(high), \(raw: buckets))", as: Int.self)
    }

    fileprivate var numeric: ISO_9075.Fragment {
        "CAST(\(self) AS NUMERIC)"
    }
}

extension QueryExpression where QueryValue == Double {
    public func exp() -> some QueryExpression<Double> {
        SQLQueryExpression("exp(\(self))", as: Double.self)
    }

    public func ln() -> some QueryExpression<Double> {
        SQLQueryExpression("ln(\(self))", as: Double.self)
    }

    public func log10() -> some QueryExpression<Double> {
        SQLQueryExpression("log10(\(self))", as: Double.self)
    }

    public func log(base: some QueryExpression<Double>) -> some QueryExpression<Double> {
        SQLQueryExpression("log(CAST(\(base) AS NUMERIC), \(numeric))", as: Double.self)
    }

    public func erf() -> some QueryExpression<Double> {
        SQLQueryExpression("erf(\(self))", as: Double.self)
    }

    public func erfc() -> some QueryExpression<Double> {
        SQLQueryExpression("erfc(\(self))", as: Double.self)
    }

    public func degrees() -> some QueryExpression<Double> {
        SQLQueryExpression("degrees(\(self))", as: Double.self)
    }

    public func radians() -> some QueryExpression<Double> {
        SQLQueryExpression("radians(\(self))", as: Double.self)
    }

    public func sin() -> some QueryExpression<Double> {
        SQLQueryExpression("sin(\(self))", as: Double.self)
    }

    public func cos() -> some QueryExpression<Double> {
        SQLQueryExpression("cos(\(self))", as: Double.self)
    }

    public func tan() -> some QueryExpression<Double> {
        SQLQueryExpression("tan(\(self))", as: Double.self)
    }

    public func cot() -> some QueryExpression<Double> {
        SQLQueryExpression("cot(\(self))", as: Double.self)
    }

    public func asin() -> some QueryExpression<Double> {
        SQLQueryExpression("asin(\(self))", as: Double.self)
    }

    public func acos() -> some QueryExpression<Double> {
        SQLQueryExpression("acos(\(self))", as: Double.self)
    }

    public func atan() -> some QueryExpression<Double> {
        SQLQueryExpression("atan(\(self))", as: Double.self)
    }

    public func atan2(_ x: some QueryExpression<Double>) -> some QueryExpression<Double> {
        SQLQueryExpression("atan2(\(self), \(x))", as: Double.self)
    }

    public func sinDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("sind(\(self))", as: Double.self)
    }

    public func cosDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("cosd(\(self))", as: Double.self)
    }

    public func tanDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("tand(\(self))", as: Double.self)
    }

    public func cotDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("cotd(\(self))", as: Double.self)
    }

    public func asinDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("asind(\(self))", as: Double.self)
    }

    public func acosDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("acosd(\(self))", as: Double.self)
    }

    public func atanDegrees() -> some QueryExpression<Double> {
        SQLQueryExpression("atand(\(self))", as: Double.self)
    }

    public func atan2Degrees(_ x: some QueryExpression<Double>) -> some QueryExpression<Double> {
        SQLQueryExpression("atan2d(\(self), \(x))", as: Double.self)
    }

    public func sinh() -> some QueryExpression<Double> {
        SQLQueryExpression("sinh(\(self))", as: Double.self)
    }

    public func cosh() -> some QueryExpression<Double> {
        SQLQueryExpression("cosh(\(self))", as: Double.self)
    }

    public func tanh() -> some QueryExpression<Double> {
        SQLQueryExpression("tanh(\(self))", as: Double.self)
    }

    public func asinh() -> some QueryExpression<Double> {
        SQLQueryExpression("asinh(\(self))", as: Double.self)
    }

    public func acosh() -> some QueryExpression<Double> {
        SQLQueryExpression("acosh(\(self))", as: Double.self)
    }

    public func atanh() -> some QueryExpression<Double> {
        SQLQueryExpression("atanh(\(self))", as: Double.self)
    }
}
