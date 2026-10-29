import Foundation
import UserNotifications

/// Напоминания о парах и служебные уведомления.
enum Notifications {
    private static var center: UNUserNotificationCenter { .current() }

    /// iOS держит не больше 64 запланированных уведомлений на приложение.
    /// У iOS лимит 64 запланированных уведомления на приложение.
    private static let maxScheduled = 52
    private static let maxExams = 8
    private static let changesID = "changes"
    private static let gradesID = "grades"
    private static let sessionID = "session"
    private static let keepAliveID = "keepAlive"
    private static let testID = "test"

    /// Через сколько после последнего обновления напомнить открыть приложение,
    /// если срок сессии неизвестен. Refresh-токен без «Запомнить меня» живёт
    /// 24 часа — нужен запас.
    static let keepAliveAfter: TimeInterval = 20 * 3600
    /// За сколько до конца сессии ЛК напомнить, если её срок известен.
    static let keepAliveBefore: TimeInterval = 4 * 3600

    /// Ключ начала пары в userInfo: нажатие открывает её карточку.
    static let lessonKey = "lesson"

    static func allowed() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Показывает системный запрос, если пользователь ещё не отвечал; после
    /// отказа iOS запрос больше не показывает и сразу возвращает false.
    static func request() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Как в карточке Live Activity: название, под ним «Лекция · аудитория»,
    /// затем когда.
    /// Текст напоминания — и для запуска Live Activity по расписанию.
    static func reminderText(_ lesson: Lesson, minutes: Int) -> (title: String, body: String) {
        (lesson.subject, [
            [lesson.kind.capitalizedFirst, lesson.placeLabel].filter { !$0.isEmpty }.joined(separator: " · "),
            "Через \(durationText(Double(minutes) * 60)), в \(hm(lesson.start))",
        ].joined(separator: "\n"))
    }

    private static func reminder(_ lesson: Lesson, minutes: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        (content.title, content.body) = reminderText(lesson, minutes: minutes)
        content.sound = .default
        // В одну стопку, чтобы напоминания за день не расползались по экрану.
        content.threadIdentifier = "lessons"
        content.userInfo = [lessonKey: lesson.start.timeIntervalSince1970]
        return content
    }

    /// Перепланирует напоминания: [minutes] до начала каждой пары, 0 — выключено.
    static func scheduleReminders(_ lessons: [Lesson], minutes: Int) async {
        // Только запланированные: уже показанное «расписание изменилось» не трогаем.
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { ![changesID, gradesID, sessionID, keepAliveID].contains($0) && !$0.hasPrefix("exam-") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        await removeStale()
        guard minutes > 0 else { return }
        let now = Date()
        // О первой паре дня напомнит запуск Live Activity по расписанию.
        let viaActivity = LiveActivities.scheduledLesson
        let upcoming = lessons
            .filter { !$0.cancelled && $0.start != viaActivity }
            .map { ($0, $0.start.addingTimeInterval(-Double(minutes) * 60)) }
            .filter { $0.1 > now }
            .prefix(maxScheduled)
        for (i, (lesson, at)) in upcoming.enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSinceNow, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "lesson-\(i)",
                                                        content: reminder(lesson, minutes: minutes), trigger: trigger))
        }
    }

    /// Накануне зачёта или экзамена в это время — напоминание.
    private static let examEveningHour = 19

    /// Вечером накануне каждого зачёта и экзамена. Не зависит от напоминаний
    /// о парах: их можно выключить, а про экзамен знать нужно.
    static func scheduleExamReminders(_ lessons: [Lesson]) async {
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("exam-") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        let now = Date()
        let shift = Clock.shift
        guard let session = ExamSession(lessons: lessons, plan: StudyPlan.cached(), now: now.addingTimeInterval(shift))
        else { return }
        for (i, exam) in session.all.compactMap(\.event).prefix(maxExams).enumerated() {
            // По настоящим часам: в сборке для скриншотов время сдвинуто.
            let start = exam.start.addingTimeInterval(-shift)
            guard let at = calendar.date(bySettingHour: examEveningHour, minute: 0, second: 0,
                                         of: start.adding(days: -1)), at > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Завтра \(exam.kind): \(exam.subject)"
            content.body = "\(hm(exam.start)) · \(exam.isRemote ? "дистанционно" : exam.placeLabel)"
            content.sound = .default
            content.userInfo = [lessonKey: start.timeIntervalSince1970]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: at.timeIntervalSinceNow, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "exam-\(i)", content: content, trigger: trigger))
        }
    }

    /// Отладка: напоминание через 5 секунд — успеть заблокировать телефон.
    static func showTest(_ lesson: Lesson, minutes: Int) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: testID,
                                                    content: reminder(lesson, minutes: minutes), trigger: trigger))
    }

    /// Начало пары из уведомления — нашего или оставшегося от Flutter-версии
    /// (там было «payload»: «lesson:<мс>»).
    static func lessonStart(_ userInfo: [AnyHashable: Any]) -> Date? {
        if let s = userInfo[lessonKey] as? Double { return Date(timeIntervalSince1970: s) }
        if let p = userInfo["payload"] as? String, p.hasPrefix("lesson:"), let ms = Double(p.dropFirst(7)) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        return nil
    }

    /// Убирает показанные напоминания о парах, которые уже начались: сами
    /// уведомления исчезать не умеют, а под Live Activity они только мешают.
    static func removeStale() async {
        let now = Date()
        let stale = await center.deliveredNotifications()
            .filter { lessonStart($0.request.content.userInfo).map { $0 <= now } ?? false }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: stale)
    }

    private static func show(_ id: String, title: String, body: String, at date: Date? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = date.map {
            UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0.timeIntervalSinceNow), repeats: false)
        }
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Одно уведомление на все изменения: первые строки и «и ещё N».
    static func showChanges(_ changes: [String]) async {
        guard !changes.isEmpty else { return }
        let shown = 3
        var lines = Array(changes.prefix(shown))
        if changes.count > shown { lines.append("и ещё \(changes.count - shown)") }
        await show(changesID, title: changes.count == 1 ? "Изменение в расписании" : "Изменения в расписании",
                   body: lines.joined(separator: "\n"))
    }

    /// «Информатика: 16 → 24 балла» — одно уведомление на все предметы.
    static func showGrades(_ changes: [String]) async {
        guard !changes.isEmpty else { return }
        let shown = 3
        var lines = Array(changes.prefix(shown))
        if changes.count > shown { lines.append("и ещё \(changes.count - shown)") }
        await show(gradesID, title: "Новые баллы", body: lines.joined(separator: "\n"))
    }

    static func showSessionExpired() async {
        await show(sessionID, title: "Расписание не обновляется",
                   body: "Сессия ЛК истекла. Открой приложение и войди заново.")
    }

    /// «Таймер мёртвой руки»: каждое успешное обновление переносит уведомление
    /// на [keepAliveAfter] вперёд (или раньше, если токен истекает раньше).
    /// Срок токена «на 30 дней» не верим: на деле сессия держится сутки.
    /// Если iOS перестала будить приложение, пользователь узнает об этом до
    /// того, как сессия истечёт.
    static func scheduleKeepAlive(lastSync: Date, sessionUntil: Date?) async {
        cancelKeepAlive()
        let at = min(lastSync.addingTimeInterval(keepAliveAfter),
                     sessionUntil.map { $0.addingTimeInterval(-keepAliveBefore) } ?? .distantFuture)
        guard at > Date() else { return }
        await show(keepAliveID, title: "Открой приложение",
                   body: "Расписание давно не обновлялось. Открой приложение, иначе придётся заново входить в ЛК.",
                   at: at)
    }

    static func cancelKeepAlive() {
        center.removePendingNotificationRequests(withIdentifiers: [keepAliveID])
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
