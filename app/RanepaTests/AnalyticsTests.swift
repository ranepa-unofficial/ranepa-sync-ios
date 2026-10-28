import XCTest
@testable import Ranepa

final class AnalyticsTests: XCTestCase {
    func testReason() {
        XCTAssertEqual(Analytics.reason(LKError.needLogin), "session")
        XCTAssertEqual(Analytics.reason(LKError.serverBusy(status: 503, retryAfter: nil)), "server")
        XCTAssertEqual(Analytics.reason(URLError(.notConnectedToInternet)), "network")
        XCTAssertEqual(Analytics.reason(LKError.message("Нет пар")), "other")
    }

    /// Раз в календарный день, даже если с прошлого раза прошло меньше суток.
    func testDailyOncePerDay() {
        let evening = date(2026, 10, 26, 23, 50)
        XCTAssertTrue(Analytics.dailyDue(last: nil, now: evening))
        XCTAssertFalse(Analytics.dailyDue(last: date(2026, 10, 26, 8, 0), now: evening))
        XCTAssertTrue(Analytics.dailyDue(last: evening, now: date(2026, 10, 27, 0, 10)))
    }
}
