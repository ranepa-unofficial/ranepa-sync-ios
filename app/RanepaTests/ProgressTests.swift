import XCTest
@testable import Ranepa

/// Ответ `dashboard/progress` — в той же форме, что приходит из ЛК.
@MainActor
final class ProgressTests: XCTestCase {
    private var d: UserDefaults!
    private let day = date(2026, 10, 30, 12)

    override func setUp() {
        d = UserDefaults(suiteName: "ProgressTests")!
        d.removePersistentDomain(forName: "ProgressTests")
    }

    private func raw(_ points: [Int], months: [(String, Int, Int)] = [("Сентябрь", 63, 41), ("Октябрь", 77, 57), ("Ноябрь", 63, 0)],
                     avg: Any = NSNull()) -> [String: Any] {
        let labels = [
            "Информатика [1 семестр] [Иванова И.И.] [ОБ-1курс 1сем.-гр.6]",
            "Иностранный язык_ОАФ_1 курс_B1-B2 [1 семестр] [] []",
            "Элективные дисциплины по физической культуре и спорту [1 семестр] [Петров П.П.] [753_юз_1_вт3_об]",
        ]
        return ["brs": ["labels": Array(labels.prefix(points.count)), "data": points],
                "visits": ["items": months.map { ["monthName": $0.0, "maxValue": $0.1, "currentValue": $0.2] }],
                "avg_brs": avg, "rating": NSNull()]
    }

    func testSubjectNames() {
        XCTAssertEqual(Progress.subjectName("Иностранный язык_ОАФ_1 курс_B1-B2 [1 семестр] [] []"), "Иностранный язык")
        XCTAssertEqual(Progress.subjectName("Основы российской государственности_ОАФ_1 курс [1 семестр] [] []"),
                       "Основы российской государственности")
        XCTAssertEqual(Progress.subjectName("Высшая математика [1 семестр] [Иванова И.И.] [гр.1, гр.2]"), "Высшая математика")
    }

    func testParse() throws {
        let p = try XCTUnwrap(Progress(raw([16, 17, 0]), at: day))
        XCTAssertEqual(p.subjects.map(\.name), ["Информатика", "Иностранный язык",
                                               "Элективные дисциплины по физической культуре и спорту"])
        XCTAssertEqual(p.points(for: "иностранный язык"), 17)
        XCTAssertEqual(p.averagePoints, 11)
        XCTAssertNil(p.averageBrs)
        XCTAssertEqual(p.currentMonth?.name, "Октябрь")
        XCTAssertEqual(percent(p.currentMonth!), 74)
    }

    func testAverageFromLK() throws {
        let p = try XCTUnwrap(Progress(raw([80], avg: "78,5"), at: day))
        XCTAssertEqual(p.averageBrs, "78,5")
    }

    func testChangesForNotification() throws {
        let old = try XCTUnwrap(Progress(raw([16, 17]), at: day))
        let new = try XCTUnwrap(Progress(raw([24, 17]), at: day))
        XCTAssertEqual(Progress.changes(from: old, to: new), ["Информатика: 16 → 24 балла"])
    }

    /// Пустой ответ ЛК не стирает сохранённые баллы и не даёт изменений.
    func testEmptyResponseKeepsCache() {
        _ = Sync.saveProgress(raw([16]), d)
        XCTAssertEqual(Sync.saveProgress(["brs": ["labels": [], "data": []], "visits": ["items": []]], d), [])
        XCTAssertEqual(Progress.cached(d)?.points(for: "Информатика"), 16)
    }

    func testWeekDelta() throws {
        try XCTUnwrap(Progress(raw([10]), at: day.adding(days: -8))).save(d)
        try XCTUnwrap(Progress(raw([12]), at: day.adding(days: -3))).save(d)
        try XCTUnwrap(Progress(raw([16]), at: day)).save(d)
        XCTAssertEqual(History.weekDelta("Информатика", now: day, d), 6)
        XCTAssertNil(History.weekDelta("Иностранный язык", now: day, d))
    }
}
