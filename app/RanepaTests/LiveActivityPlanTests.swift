import XCTest
@testable import Ranepa

/// Когда Live Activity видна и когда запускается по расписанию.
final class LiveActivityPlanTests: XCTestCase {
    typealias A = LessonActivityAttributes

    private func pair(_ day: Int, _ hour: Int, _ minute: Int = 0) -> A.Lesson {
        let start = date(2026, 10, day, hour, minute)
        return A.Lesson(title: "Пара \(day) \(hour):\(minute)", kind: "Лекция", room: "1 - 101", fullRoom: "",
                        start: start, end: start.addingTimeInterval(80 * 60))
    }

    /// Вторник 13-го: пары в 9:00 и 10:40; среда 14-го: 12:20.
    private lazy var week = [pair(13, 9), pair(13, 10, 40), pair(14, 12, 20)]

    private func plan(_ now: Date, running: Bool = false, minutes: Int = 15) -> LiveActivityPlan {
        LiveActivityPlan(week, now: now, running: running, reminderMinutes: minutes)
    }

    /// Ночью сегодняшние пары не показываем — только запуск вместе с напоминанием.
    func testNightSchedulesWithReminder() {
        let p = plan(date(2026, 10, 13, 1))
        XCTAssertFalse(p.startNow)
        XCTAssertEqual(p.scheduled?.at, date(2026, 10, 13, 8, 45))
        XCTAssertEqual(p.scheduled?.state.lesson, week[0])
        XCTAssertEqual(p.scheduled?.state.next, week[1])
    }

    func testStartsTwoHoursBefore() {
        XCTAssertFalse(plan(date(2026, 10, 13, 6, 59)).startNow)
        let p = plan(date(2026, 10, 13, 7))
        XCTAssertTrue(p.startNow)
        XCTAssertFalse(p.today?.isCurrent ?? true)
        // Сегодняшняя уже запускается — по расписанию следующий день.
        XCTAssertEqual(p.scheduled?.at, date(2026, 10, 14, 12, 5))
    }

    func testDuringLesson() {
        let p = plan(date(2026, 10, 13, 9, 30), running: true)
        XCTAssertFalse(p.startNow)
        XCTAssertEqual(p.today?.lesson, week[0])
        XCTAssertTrue(p.today?.isCurrent ?? false)
        XCTAssertEqual(p.today?.next, week[1])
    }

    /// После последней пары дня активность не нужна.
    func testEndsAfterLastLesson() {
        let p = plan(date(2026, 10, 13, 12, 1), running: true)
        XCTAssertNil(p.today)
        XCTAssertFalse(p.startNow)
        XCTAssertEqual(p.scheduled?.at, date(2026, 10, 14, 12, 5))
    }

    /// Длинное окно: уже идущая активность остаётся до конца дня.
    func testLongBreakKeepsRunning() {
        let lessons = [pair(13, 9), pair(13, 16)]
        let now = date(2026, 10, 13, 11)
        let p = LiveActivityPlan(lessons, now: now, running: true, reminderMinutes: 15)
        XCTAssertEqual(p.today?.lesson, lessons[1])
        XCTAssertFalse(p.startNow)
        // А новую в окне не запускаем: до пары больше 2 часов.
        XCTAssertFalse(LiveActivityPlan(lessons, now: now, running: false, reminderMinutes: 15).startNow)
    }

    /// Напоминания выключены — без запуска по расписанию.
    func testNoScheduleWithoutReminders() {
        XCTAssertNil(plan(date(2026, 10, 13, 1), minutes: 0).scheduled)
    }

    /// Сегодня уже идёт — по расписанию только следующий день.
    func testScheduleSkipsStartedDay() {
        let p = plan(date(2026, 10, 13, 8, 50), running: true)
        XCTAssertEqual(p.scheduled?.state.lesson, week[2])
    }

    // MARK: Изменения пар в активности

    private func lesson(_ title: String, _ hour: Int, _ minute: Int = 0, room: String = "2 - 2016") -> A.Lesson {
        let start = date(2026, 10, 13, hour, minute)
        return A.Lesson(title: title, kind: "семинар", room: room, fullRoom: "", start: start, end: start.addingTimeInterval(80 * 60))
    }

    private lazy var shown = A.ContentState(lesson: lesson("Математика", 9), next: lesson("Философия", 12, 20), isCurrent: true)
    private let morning = date(2026, 10, 13, 9, 30)

    func testNoChange() {
        XCTAssertNil(LiveActivityPlan.change(from: shown, to: [lesson("Математика", 9), lesson("Философия", 12, 20)], now: morning))
    }

    func testRoomChanged() {
        let c = LiveActivityPlan.change(from: shown, to: [lesson("Математика", 9), lesson("Философия", 12, 20, room: "5 - 301")],
                                        now: morning)
        XCTAssertEqual(c?.kind, .room)
        XCTAssertEqual(c?.old, "2 - 2016")
        XCTAssertEqual(c?.new, "5 - 301")
        XCTAssertEqual(c?.lesson.title, "Философия")
        XCTAssertEqual(c.map(changeBody), "Философия, 12:20: 2 - 2016 → 5 - 301")
    }

    func testMoved() {
        let c = LiveActivityPlan.change(from: shown, to: [lesson("Математика", 9), lesson("Философия", 14)], now: morning)
        XCTAssertEqual(c?.kind, .time)
        XCTAssertEqual(c?.old, "12:20")
        XCTAssertEqual(c?.new, "14:00")
    }

    func testCancelled() {
        let c = LiveActivityPlan.change(from: shown, to: [lesson("Математика", 9)], now: morning)
        XCTAssertEqual(c?.kind, .cancelled)
        XCTAssertNil(c?.new)
        XCTAssertEqual(c.map(changeBody), "Философия, 12:20")
    }

    /// Закончившаяся пара пропала из расписания — это не изменение.
    func testFinishedLessonIgnored() {
        XCTAssertNil(LiveActivityPlan.change(from: shown, to: [lesson("Философия", 12, 20)], now: date(2026, 10, 13, 11)))
    }
}
