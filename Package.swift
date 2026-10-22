// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-postgresql",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "PostgreSQL", targets: ["PostgreSQL"]),
        .library(name: "PostgreSQL Test Support", targets: ["PostgreSQL Test Support"]),
    ],
    traits: [
        .trait(name: "PostgresNIO", description: "Connection, pools, transactions, notifications and decoding over PostgresNIO"),
        .trait(name: "Tagged", description: "PostgreSQL conformances for swift-atoms Tagged"),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.81.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.3.3"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.18.4"),
        .package(
            url: "https://github.com/swift-compositions/swift-sql.git",
            branch: "main",
            traits: [.trait(name: "Tagged", condition: .when(traits: ["Tagged"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4122.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
        .package(
            url: "https://github.com/vapor/postgres-nio.git",
            revision: "b6cca02c7e0a223814ec45f1a6114983b2fa3c74"
        ),
    ],
    targets: [
        .target(
            name: "PostgreSQL",
            dependencies: [
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "PostgresNIO", package: "postgres-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "NIOCore", package: "swift-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "Logging", package: "swift-log", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ]
        ),
        .target(
            name: "PostgreSQL Test Support",
            dependencies: [
                "PostgreSQL",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "PostgresNIO", package: "postgres-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "Logging", package: "swift-log", condition: .when(traits: ["PostgresNIO"])),
            ]
        ),
        .testTarget(
            name: "PostgreSQL Tests",
            dependencies: [
                "PostgreSQL",
                "PostgreSQL Test Support",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "PostgresNIO", package: "postgres-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "Logging", package: "swift-log", condition: .when(traits: ["PostgresNIO"])),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
