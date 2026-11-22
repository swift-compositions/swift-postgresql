import Byte
import RFC_4122
import SQL
import SQL_Macros
import Time

enum NotificationFixtures {
    @Table("events")
    struct Event: Equatable, Sendable {
        let id: Int
        var title: String
        var happenedAt: Time.Instant
        var reference: IETF.RFC.`4122`.UUID?
        var payload: [Byte]
        var isPublic: Bool
        var weight: Double?
    }
}
