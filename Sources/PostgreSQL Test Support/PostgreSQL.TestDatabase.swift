public import PostgreSQL
#if PostgresNIO && !os(Windows)
    public import ISO_9075_Call_Level_Interface
    internal import Foundation
    public import Testing

    extension PostgreSQL {
        public enum TestDatabase {
            @TaskLocal public static var current: PostgreSQL.Database?

            public static var database: PostgreSQL.Database {
                guard let current else {
                    preconditionFailure("PostgreSQL.TestDatabase.database is available inside a suite marked .postgreSQL(…) only")
                }
                return current
            }
        }
    }

    extension PostgreSQL.TestDatabase {
        public struct Scope: SuiteTrait, TestScoping {
            public let configuration: PostgreSQL.Configuration
            public let setUp: [ISO_9075.Fragment]

            public init(configuration: PostgreSQL.Configuration, setUp: [ISO_9075.Fragment]) {
                self.configuration = configuration
                self.setUp = setUp
            }

            public var isRecursive: Bool { false }

            public func provideScope(
                for test: Test,
                testCase: Test.Case?,
                performing function: @concurrent @Sendable () async throws -> Void
            ) async throws {
                let name = ISO_9075.Identifier("swift_postgresql_\(String(UInt64.random(in: .min ... .max), radix: 16))")
                var isolated = configuration
                isolated.database = name.name
                isolated.poolSize = 4
                var single = configuration
                single.poolSize = 1
                var administration = try PostgreSQL.Database(configuration: single)
                let database = try PostgreSQL.Database(configuration: isolated)
                defer { _ = (administration, database) }
                do {
                    do {
                        try await create(name, on: administration)
                    } catch let error as PostgreSQL.Error where error.code == .invalidCatalogName {
                        // No database of the configured name to administer from: every server has `postgres`.
                        await administration.close()
                        single.database = "postgres"
                        administration = try PostgreSQL.Database(configuration: single)
                        try await create(name, on: administration)
                    }
                } catch let error as PostgreSQL.Error {
                    let unreachable = [.connect, .timeout].contains(error.kind)
                    guard unreachable, ProcessInfo.processInfo.environment["POSTGRES_HOST"] == nil else { throw error }
                    await administration.close()
                    try Test.cancel("No PostgreSQL server is reachable at the default address and POSTGRES_HOST is unset: \(error)")
                }
                do {
                    for statement in setUp {
                        _ = try await database.execute(statement)
                    }
                    try await PostgreSQL.TestDatabase.$current.withValue(database) {
                        try await function()
                    }
                } catch {
                    await database.close()
                    try await drop(name, on: administration)
                    await administration.close()
                    throw error
                }
                await database.close()
                try await drop(name, on: administration)
                await administration.close()
            }

            private func create(_ name: ISO_9075.Identifier, on administration: PostgreSQL.Database) async throws {
                _ = try await administration.writeWithoutTransaction { connection in
                    try connection.execute("CREATE DATABASE \(name)")
                }
            }

            private func drop(_ name: ISO_9075.Identifier, on administration: PostgreSQL.Database) async throws {
                _ = try await administration.writeWithoutTransaction { connection in
                    try connection.execute("DROP DATABASE \(name) WITH (FORCE)")
                }
            }
        }
    }

    extension Trait where Self == PostgreSQL.TestDatabase.Scope {
        public static func postgreSQL(
            configuration: PostgreSQL.Configuration,
            setUp: [ISO_9075.Fragment]
        ) -> Self {
            Self(configuration: configuration, setUp: setUp)
        }
    }
#endif
