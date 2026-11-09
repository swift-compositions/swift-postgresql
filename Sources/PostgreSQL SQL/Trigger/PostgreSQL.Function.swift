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

        public func create(orReplace: Bool = true, body: String) -> SQLQueryExpression<()> {
            precondition(!body.contains("$function$"), "a trigger function body must not contain $function$")
            return SQLQueryExpression(
                "CREATE \(raw: orReplace ? "OR REPLACE " : "")FUNCTION \(reference)() RETURNS trigger LANGUAGE plpgsql AS $function$\n\(raw: body)\n$function$"
            )
        }

        public func drop(ifExists: Bool = false, cascade: Bool = false) -> SQLQueryExpression<()> {
            SQLQueryExpression(
                "DROP FUNCTION \(raw: ifExists ? "IF EXISTS " : "")\(reference)()\(raw: cascade ? " CASCADE" : "")"
            )
        }
    }
}
