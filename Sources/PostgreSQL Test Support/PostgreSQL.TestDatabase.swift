#if PostgresNIO
    public import ISO_9075_Call_Level_Interface
    public import Logging
    internal import NIOPosix
    internal import Foundation
    public import PostgreSQL
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
                let logger = Logger(label: "swift-postgresql.tests")
                let name = ISO_9075.Identifier("swift_postgresql_\(String(UInt64.random(in: .min ... .max), radix: 16))")
                var isolated = configuration
                isolated.database = name.name
                let administration = PostgreSQL.Database(
                    configuration: configuration,
                    connections: 1...1,
                    threadPool: .singleton,
                    logger: logger
                )
                let database = PostgreSQL.Database(
                    configuration: isolated,
                    connections: 1...4,
                    threadPool: .singleton,
                    logger: logger
                )
                try await withThrowingTaskGroup { group in
                    group.addTask { await administration.run() }
                    defer { group.cancelAll() }
                    do {
                        _ = try await administration.writeWithoutTransaction { connection throws(ISO_9075.Error) in
                            try connection.execute("CREATE DATABASE \(name)")
                        }
                    } catch ISO_9075.Error.connection(let reason) where ProcessInfo.processInfo.environment["POSTGRES_HOST"] == nil {
                        try Test.cancel("No PostgreSQL server is reachable at the default address and POSTGRES_HOST is unset: \(reason)")
                    }
                    do {
                        try await withThrowingTaskGroup { clients in
                            clients.addTask { await database.run() }
                            defer { clients.cancelAll() }
                            for statement in setUp {
                                _ = try await database.execute(statement)
                            }
                            try await PostgreSQL.TestDatabase.$current.withValue(database) {
                                try await function()
                            }
                        }
                    } catch {
                        try await drop(name, on: administration)
                        throw error
                    }
                    try await drop(name, on: administration)
                }
            }

            private func drop(_ name: ISO_9075.Identifier, on administration: PostgreSQL.Database) async throws(ISO_9075.Error) {
                _ = try await administration.writeWithoutTransaction { connection throws(ISO_9075.Error) in
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
