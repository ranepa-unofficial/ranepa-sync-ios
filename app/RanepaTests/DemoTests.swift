import XCTest
@testable import Ranepa

final class DemoTests: XCTestCase {
    private func lessons(at now: Date, revision: Int = 0) -> [Lesson] {
        parseLessons(Demo.result(now: now, revision: revision).days)
    }

    /// План в демо: сессия с экзаменом и зачётами видна, карточка — в пределах месяца.
    func testDemoPlanSession() throws {
        let now = date(2026, 10, 13, 11, 5)
        let result = Demo.result(now: now)
        let plan = try XCTUnwrap(result.plan.flatMap { try? JSONDecoder().decode(StudyPlan.self, from: Data($0.utf8)) })
        XCTAssertEqual(plan.currentSemester(now: now), 1)
        let session = try XCTUnwrap(ExamSession(lessons: parseLessons(result.days), plan: plan, now: now))
        XCTAssertEqual(session.exams.map(\.subject), ["Математика", "Экономическая теория"])
        XCTAssertNotNil(session.exams[0].event)
        XCTAssertEqual(session.credits.count, 5)
        XCTAssertTrue(session.showsCard(now: now))
    }

    func testTuesdayMorningRegularGrid() {
        let now = date(2026, 10, 13, 11, 5)
        let today = lessons(at: now).filter { $0.start.sameDay(now) }
        XCTAssertEqual(today.map { hm($0.start) }, ["09:00", "10:40", "12:20", "14:00"])
        XCTAssertEqual(today.filter { $0.start <= now && now < $0.end }.count, 1)
    }

    func testTodayAlwaysHasLessonsWithinDay() {
        for hour in [0, 3, 8, 15, 21, 23] {
            // Воскресенье: берётся расписание вторника.
            let now = date(2026, 10, 18, hour, 50)
            let today = lessons(at: now).filter { $0.start.sameDay(now) || $0.end.sameDay(now) }
            XCTAssertFalse(today.isEmpty, "\(hour):50")
            for l in today { XCTAssertTrue(l.start.sameDay(now) && l.end.sameDay(now)) }
        }
    }

    func testMonthWithCancellationConsultationAndCredit() {
        let now = date(2026, 10, 13, 11, 5)
        let all = lessons(at: now)
        XCTAssertGreaterThan(all.first!.start, now.monday)
        XCTAssertLessThan(all.last!.start, now.monday.adding(days: 7 * fetchWeeks))
        XCTAssertEqual(all.filter(\.cancelled).count, 1)
        XCTAssertTrue(Set(all.map(\.kind)).isSuperset(of:
            ["лекция", "семинар", "лабораторная", "физкультура", "консультация", "зачёт"]))
    }

    func testOddRevisionChangesTomorrowRoom() {
        let now = date(2026, 10, 13, 11, 5)
        let tomorrow = now.adding(days: 1)
        func first(_ revision: Int) -> Lesson { lessons(at: now, revision: revision).first { $0.start.sameDay(tomorrow) }! }
        XCTAssertNotEqual(first(1).room, first(0).room)
        XCTAssertEqual(first(2).room, first(0).room)
    }

    func testChangesDescribeMovedLesson() {
        let now = date(2026, 10, 13, 11, 5)
        let before = lessons(at: now)
        let after = lessons(at: now, revision: 1)
        let changes = describeChanges(before: before, after: after, now: now)
        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(changes[0].contains("аудитория:"), changes[0])
    }

    /// Демо-успеваемость в формате ЛК: все предметы демо-расписания с баллами,
    /// «потянуть вниз» меняет баллы по математике.
    func testDemoProgress() throws {
        let now = date(2026, 10, 13, 11)
        let progress = try XCTUnwrap(Progress(Demo.progress(now: now), at: now))
        let names = Set(parseLessons(Demo.result(now: now).days).map(\.subject))
        XCTAssertEqual(progress.subjects.count, 8)
        XCTAssertTrue(progress.subjects.allSatisfy { names.contains($0.name) }, "\(progress.subjects.map(\.name))")
        XCTAssertEqual(progress.currentMonth?.name, "Октябрь")
        let next = try XCTUnwrap(Progress(Demo.progress(now: now, revision: 1), at: now))
        XCTAssertEqual(Progress.changes(from: progress, to: next), ["Математика: 22 → 26 баллов"])
    }
}
