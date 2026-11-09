internal import ISO_9075_Foundation

extension PostgreSQL {
    public enum Window {}
}

extension PostgreSQL.Window {
    public static func rowNumber() -> Function<Int> {
        Function("row_number")
    }

    public static func rank() -> Function<Int> {
        Function("rank")
    }

    public static func denseRank() -> Function<Int> {
        Function("dense_rank")
    }

    public static func percentRank() -> Function<Double> {
        Function("percent_rank")
    }

    public static func cumeDist() -> Function<Double> {
        Function("cume_dist")
    }

    public static func ntile(_ buckets: Int) -> Function<Int> {
        precondition(buckets > 0, "ntile buckets must be positive")
        return Function("ntile", ["\(raw: buckets)"])
    }
}
