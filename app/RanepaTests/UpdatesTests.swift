import XCTest
@testable import Ranepa

@MainActor
final class UpdatesTests: XCTestCase {
    private func manifest(_ json: String) throws -> Updates.Manifest {
        try JSONDecoder().decode(Updates.Manifest.self, from: Data(json.utf8))
    }

    /// Манифест из корня репозитория должен разбираться.
    func testRepoManifestParses() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("update.json")
        let data = try Data(contentsOf: url)
        let m = try JSONDecoder().decode(Updates.Manifest.self, from: data)
        XCTAssertNotNil(m.appstore)
        XCTAssertNotNil(m.testflight)
    }

    func testVersionOrder() {
        typealias V = Updates.Version
        XCTAssertLessThan(V("2.2.0", build: 31), V("2.2.0", build: 32))
        XCTAssertLessThan(V("2.2.9", build: 99), V("2.10"))
        XCTAssertEqual(V("2.2"), V("2.2.0"))
    }

    func testAppStoreIgnoresBuild() throws {
        let m = try manifest(#"{"appstore": {"latest": "2.3.0", "minimum": "2.0.0"}}"#)
        XCTAssertEqual(Updates.status(m, source: .appStore, current: .init("2.3.0", build: 5)), .none)
        XCTAssertEqual(Updates.status(m, source: .appStore, current: .init("2.2.0", build: 99)),
                       .available(latest: "2.3.0", notes: nil))
        XCTAssertEqual(Updates.status(m, source: .appStore, current: .init("1.9.0")), .required)
    }

    func testTestFlightComparesBuilds() throws {
        let m = try manifest(#"""
        {"testflight": {"latest": "2.2.0", "latestBuild": 33, "minimum": "2.2.0", "minimumBuild": 31, "notes": "Поиск"}}
        """#)
        XCTAssertEqual(Updates.status(m, source: .testFlight, current: .init("2.2.0", build: 33)), .none)
        XCTAssertEqual(Updates.status(m, source: .testFlight, current: .init("2.2.0", build: 32)),
                       .available(latest: "2.2.0 (33)", notes: "Поиск"))
        XCTAssertEqual(Updates.status(m, source: .testFlight, current: .init("2.2.0", build: 30)), .required)
    }

    /// Нет канала или сборка из Xcode — ничего не показываем.
    func testMissingChannelAndXcode() throws {
        let m = try manifest(#"{"appstore": {"latest": "9.0", "minimum": "9.0"}}"#)
        XCTAssertEqual(Updates.status(m, source: .testFlight, current: .init("2.2.0", build: 1)), .none)
        XCTAssertEqual(Updates.status(m, source: .xcode, current: .init("1.0")), .none)
    }
}
