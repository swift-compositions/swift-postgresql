public import PostgreSQL_SQL
#if PostgresNIO && !os(Windows)
    public import ISO_9075_Call_Level_Interface
    package import PostgresNIO

    extension PostgreSQL.Notification {
        public struct Stream<Payload>: AsyncSequence {
            let notifications: PostgresNotificationSequence
            let channel: Channel<Payload>

            init(_ notifications: PostgresNotificationSequence, channel: Channel<Payload>) {
                self.notifications = notifications
                self.channel = channel
            }

            public func makeAsyncIterator() -> Iterator {
                Iterator(notifications.makeAsyncIterator(), channel: channel)
            }
        }
    }

    extension PostgreSQL.Notification.Stream {
        public struct Iterator: AsyncIteratorProtocol {
            var notifications: PostgresNotificationSequence.AsyncIterator
            let channel: PostgreSQL.Notification.Channel<Payload>

            init(_ notifications: PostgresNotificationSequence.AsyncIterator, channel: PostgreSQL.Notification.Channel<Payload>) {
                self.notifications = notifications
                self.channel = channel
            }

            public mutating func next() async throws(ISO_9075.Error) -> Payload? {
                try await next(isolation: #isolation)
            }

            public mutating func next(isolation actor: isolated (any Actor)?) async throws(ISO_9075.Error) -> Payload? {
                let notification: PostgresNotification?
                do {
                    notification = try await notifications.next(isolation: actor)
                } catch {
                    throw .connection("\(error) while listening on \(channel.name)")
                }
                return try notification.map { notification throws(ISO_9075.Error) in try channel.decode(notification.payload) }
            }
        }
    }

    extension PostgreSQL.Database {
        @concurrent
        public func listen<Payload, Value: Sendable>(
            on channel: PostgreSQL.Notification.Channel<Payload>,
            consume: (PostgreSQL.Notification.Stream<Payload>) async throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            let result: Result<Value, ISO_9075.Error>
            do {
                result = try await engine.client.withConnection { postgres in
                    try await postgres.listen(on: channel.name) { notifications in
                        do throws(ISO_9075.Error) {
                            return .success(try await consume(PostgreSQL.Notification.Stream(notifications, channel: channel)))
                        } catch {
                            return .failure(error)
                        }
                    }
                }
            } catch {
                throw .connection("\(error) while listening on \(channel.name)")
            }
            return try result.get()
        }
    }
#endif
