import BackgroundTasks
import Foundation

/// Фоновое обновление: в будни днём — раз в час, Пн–Сб не реже раза в 4 часа,
/// в воскресенье — раз в 12 (`Sync.interval`). Система запускает задачу не раньше заданного
/// времени, а когда именно — решает сама. Каждое обновление продлевает
/// сессию ЛК.
enum Background {
    /// Совпадает с BGTaskSchedulerPermittedIdentifiers в Info.plist.
    static let taskID = "com.qteb.ranepaTimetable.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        var at = Sync.nextRun(after: Date())
        // Live Activity видна — проснуться к концу последней пары и убрать её.
        if let end = LiveActivities.dayEnd(cachedLessons()), end > Date() { at = min(at, end.addingTimeInterval(60)) }
        request.earliestBeginDate = at
        try? BGTaskScheduler.shared.submit(request)
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
    }

    /// Запуск системой. Итог пишется в настройки — его видно в разделе «Отладка».
    @MainActor
    static func run(debug: Bool = false) async {
        let d = UserDefaults.standard
        guard d.bool(forKey: Keys.loggedIn), !d.bool(forKey: Keys.demo) else { return }
        // Следующий запуск — сразу: задача могла не успеть.
        schedule()
        let outcome: String
        do {
            let result = try await Sync.run(debug ? .debug : .background, d)
            await Notifications.showChanges(result.changes)
            outcome = switch result.skipped {
            case nil: result.changes.isEmpty ? "без изменений" : "изменений: \(result.changes.count)"
            case .backoff: "пауза после ошибки ЛК"
            case .tooSoon: "рано, пропущено"
            case .notNeeded: "нет пар, пропущено"
            case .needLogin: "нужно войти в ЛК"
            }
        } catch LKError.needLogin {
            // Остаёмся в приложении с сохранённым расписанием, на главном
            // экране — просьба войти заново.
            d.set(true, forKey: Keys.sessionExpired)
            Notifications.cancelKeepAlive()
            if !d.bool(forKey: Keys.sessionExpiredNotified) {
                await Notifications.showSessionExpired()
                d.set(true, forKey: Keys.sessionExpiredNotified)
            }
            outcome = "сессия истекла"
        } catch {
            outcome = "ошибка: \(error.localizedDescription)"
        }
        // Активность — по сохранённому расписанию, даже если ЛК не ответил:
        // после последней пары её нужно убрать.
        let minutes = d.object(forKey: Keys.reminderMinutes) == nil
            ? defaultReminderMinutes : d.integer(forKey: Keys.reminderMinutes)
        await LiveActivities.update(cachedLessons(d), enabled: d.bool(Keys.liveActivity, default: true),
                                    reminderMinutes: minutes)
        d.setTime(Date(), Keys.lastBackgroundRun)
        d.set(outcome, forKey: Keys.lastBackgroundResult)
    }

    /// Отладка: сдвигает в кэше ближайшую будущую пару на час раньше, чтобы
    /// следующее обновление нашло «перенос» и прислало уведомление.
    static func debugShiftNextLesson() {
        var days = cachedDays()
        let now = Date()
        // Дни в кэше не по порядку: ищем самую раннюю будущую пару, иначе
        // можно сдвинуть пару через месяц — об изменениях дальше недели
        // уведомление не приходит.
        var nearest: (day: Int, disc: Int, start: Date)?
        for (i, day) in days.enumerated() {
            let discs = (day as? [String: Any])?["discs"] as? [[String: Any]] ?? []
            for (j, disc) in discs.enumerated() {
                guard let start = moscowDate("\(disc["start_date"] ?? "")"), start > now else { continue }
                if nearest.map({ start < $0.start }) ?? true { nearest = (i, j, start) }
            }
        }
        guard let nearest, var dayDict = days[nearest.day] as? [String: Any],
              var discs = dayDict["discs"] as? [[String: Any]],
              let end = moscowDate("\(discs[nearest.disc]["end_date"] ?? "")") else { return }
        discs[nearest.disc]["start_date"] = moscowStamp(nearest.start.addingTimeInterval(-3600))
        discs[nearest.disc]["end_date"] = moscowStamp(end.addingTimeInterval(-3600))
        dayDict["discs"] = discs
        days[nearest.day] = dayDict
        saveDays(days)
    }
}
