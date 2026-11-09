import Foundation
import Testing

/// The engine stays sealed: no public symbol, signature, conformance or extension of `PostgreSQL SQL`, `PostgreSQL`
/// or `PostgreSQL Test Support` names a module of the engine underneath, so replacing the engine changes nothing a
/// consumer can see (#23, decision 5).
@Suite struct `The public API` {
    static let engine = ["PostgresNIO", "NIOCore", "NIOPosix", "NIOSSL", "NIOConcurrencyHelpers", "Logging"]

    static let products = ["PostgreSQL_SQL", "PostgreSQL", "PostgreSQL_Test_Support"]

    @Test(.timeLimit(.minutes(30)))
    func `names no module of the engine, with every trait on`() throws {
        let graphs = try Self.dumpSymbolGraphs()
        let files = try FileManager.default.contentsOfDirectory(atPath: graphs.path)
            .filter { $0.hasSuffix(".symbols.json") }

        for product in Self.products {
            #expect(files.contains("\(product).symbols.json"), "no symbol graph for \(product) in \(graphs.path)")
        }

        var checked = 0
        for file in files {
            let modules = file.dropLast(".symbols.json".count).split(separator: "@").map(String.init)
            guard let module = modules.first, Self.products.contains(module) else { continue }
            checked += 1
            if modules.count > 1, Self.engine.contains(modules[1]) {
                Issue.record("\(module) publicly extends \(modules[1]): \(file)")
            }
            let text = try String(contentsOf: graphs.appending(path: file), encoding: .utf8)
            for name in Self.engine {
                for leak in Self.mentions(of: name, in: text) {
                    Issue.record("\(file) names \(name): …\(leak)…")
                }
            }
        }
        #expect(checked >= Self.products.count)
    }

    /// Where the symbol graph mentions `module`: a mangled name of one of its symbols, as in a USR
    /// (`s:11PostgresNIO14PostgresClientC`), or a qualified name, as in a conformance's fallback
    /// (`PostgresNIO.PostgresEncodable`).
    static func mentions(of module: String, in text: String) -> [String] {
        let mangled = try! Regex("(?:^|[^0-9])\(module.utf8.count)\(module)")
        let qualified = try! Regex("(?:^|[^A-Za-z0-9_])\(module)\\.[A-Za-z_]")
        return (text.matches(of: mangled) + text.matches(of: qualified)).map { match in
            let start = text.index(match.range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
            let end = text.index(match.range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[start..<end])
        }
    }

    /// Builds the package with every trait on, in a scratch folder of its own, and dumps the public symbol graph of
    /// each of its modules. Returns the folder the graphs were written to.
    static func dumpSymbolGraphs() throws -> URL {
        let package = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratch = package.appending(path: ".build/public-api")
        let log = scratch.appending(path: "dump.log")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }

        let swift = Process()
        swift.executableURL = URL(filePath: "/usr/bin/env")
        swift.arguments = [
            "swift", "package",
            "--package-path", package.path,
            "--scratch-path", scratch.path,
            "dump-symbol-graph",
            "--enable-all-traits",
            "--minimum-access-level", "public",
            // Inherited default implementations are left out: the graph would otherwise list the engine's own
            // extensions of standard protocols (PostgresNIO's `RawRepresentable.postgresData`) as members of every
            // public RawRepresentable type here, which a consumer sees only by importing the engine itself.
            "--skip-synthesized-members",
        ]
        swift.standardOutput = output
        swift.standardError = output
        try swift.run()
        swift.waitUntilExit()

        let transcript = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        guard swift.terminationStatus == 0 else {
            throw DumpFailure(status: swift.terminationStatus, transcript: String(transcript.suffix(4000)))
        }
        guard let line = transcript.split(separator: "\n").last(where: { $0.hasPrefix("Files written to ") }) else {
            throw DumpFailure(status: 0, transcript: String(transcript.suffix(4000)))
        }
        return URL(filePath: String(line.dropFirst("Files written to ".count)))
    }

    struct DumpFailure: Error, CustomStringConvertible {
        let status: Int32
        let transcript: String
        var description: String { "swift package dump-symbol-graph exited \(status):\n\(transcript)" }
    }
}
