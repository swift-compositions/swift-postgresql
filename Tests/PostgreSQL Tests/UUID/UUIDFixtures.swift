import RFC_4122
import SQL
import SQL_Macros

enum UUIDFixtures {
    @Table("users")
    struct User {
        let id: IETF.RFC.`4122`.UUID
        let name: String
        let referrerID: IETF.RFC.`4122`.UUID?
    }
}
