internal import ISO_9075_Foundation
public import SQL

extension PostgreSQL {
    public struct Function: Sendable, Hashable {
        public let name: String
        public let schema: String?

        public init(_ name: String, schema: String? = nil) {
            precondition(!name.isEmpty, "a function needs a name")
            self.name = name
            self.schema = schema
        }

        var reference: ISO_9075.Fragment {
            schema.map { schema -> ISO_9075.Fragment in "\(quote: schema).\(quote: name)" } ?? "\(quote: name)"
        }

        /// `CREATE FUNCTION … RETURNS trigger LANGUAGE plpgsql` with `body` dollar-quoted, under `$function$` or, when
        /// the body contains that, the first of `$function_1$`, `$function_2$`, … it doesn't contain.
        public func create(orReplace: Bool = true, body: String) -> SQLQueryExpression<()> {
            let tag = Self.tag(for: body)
            return SQLQueryExpression(
                "CREATE \(raw: orReplace ? "OR REPLACE " : "")FUNCTION \(reference)() RETURNS trigger LANGUAGE plpgsql AS \(raw: tag)\n\(raw: body)\n\(raw: tag)"
            )
        }

        /// A dollar-quote tag that `body` does not contain, so the body can't end the quote early.
        static func tag(for body: String) -> String {
            var tag = "$function$"
            var number = 0
            while body.contains(tag) {
                number += 1
                tag = "$function_\(number)$"
            }
            return tag
        }

        public func drop(ifExists: Bool = false, cascade: Bool = false) -> SQLQueryExpression<()> {
            SQLQueryExpression(
                "DROP FUNCTION \(raw: ifExists ? "IF EXISTS " : "")\(reference)()\(raw: cascade ? " CASCADE" : "")"
            )
        }
    }
}
