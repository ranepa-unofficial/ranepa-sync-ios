import Foundation

/// Ключи настроек и кэша в UserDefaults. Названия те же, что были во Flutter:
/// при первом запуске после обновления данные переносятся как есть.
enum Keys {
    static let loggedIn = "loggedIn"
    static let days = "days"
    static let group = "group"
    static let fetchedAt = "fetchedAt"
    static let rangeStart = "rangeStart"
    static let reminderMinutes = "reminderMinutes"
    static let calendarExport = "calendarExport"
    static let sessionExpiredNotified = "sessionExpiredNotified"
    /// Сессия ЛК истекла: расписание показываем из кэша и просим войти заново.
    static let sessionExpired = "sessionExpired"
    static let lastBackgroundRun = "lastBackgroundRun"
    static let lastBackgroundResult = "lastBackgroundResult"
    static let fullName = "fullName"
    static let program = "program"
    static let photo = "photo"
    static let photoFetchedAt = "photoFetchedAt"
    static let lastFullAt = "lastFullAt"
    /// Когда последний раз загружали весь семестр.
    static let lastSemesterAt = "lastSemesterAt"
    static let lastAttemptAt = "lastAttemptAt"
    static let backoffUntil = "backoffUntil"
    static let backoffFailures = "backoffFailures"
    static let liveActivity = "liveActivity"
    /// Когда запустится Live Activity по расписанию.
    static let liveActivityStartAt = "liveActivityStartAt"
    static let themeMode = "themeMode"
    static let demo = "demo"
    static let demoRevision = "demoRevision"
    static let demoShift = "demoShift"
    static let demoFastFrom = "demoFastFrom"
    /// Когда истекает сессия ЛК (refresh-токен), по настоящим часам.
    static let sessionUntil = "sessionUntil"
    /// План обучения из ЛК (JSON StudyPlan).
    static let plan = "plan"
    /// Когда последний раз отправили, какие функции включены.
    static let analyticsDailyAt = "analyticsDailyAt"

    /// Всё, что относится к сессии и удаляется при выходе.
    static let session = [
        loggedIn, days, group, fetchedAt, rangeStart, sessionExpiredNotified, sessionExpired,
        lastBackgroundRun, lastBackgroundResult, fullName, program, photo,
        photoFetchedAt, lastFullAt, lastSemesterAt, lastAttemptAt, backoffUntil, backoffFailures,
        demo, demoRevision, demoShift, demoFastFrom, sessionUntil, plan,
    ]
}

extension UserDefaults {
    /// Моменты времени хранятся в миллисекундах, как во Flutter-версии.
    func time(_ key: String) -> Date? {
        guard object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: Double(integer(forKey: key)) / 1000)
    }

    func setTime(_ date: Date?, _ key: String) {
        guard let date else { return removeObject(forKey: key) }
        set(Int((date.timeIntervalSince1970 * 1000).rounded()), forKey: key)
    }

    func bool(_ key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }

    /// Flutter (shared_preferences) хранил всё в этом же UserDefaults
    /// с приставкой «flutter.». Переносим один раз: сессия ЛК в WKWebView
    /// и так общая, поэтому заново входить не придётся.
    func migrateFromFlutter() {
        let marker = "migratedFromFlutter"
        guard !bool(forKey: marker) else { return }
        for (key, value) in dictionaryRepresentation() where key.hasPrefix("flutter.") {
            set(value, forKey: String(key.dropFirst("flutter.".count)))
            removeObject(forKey: key)
        }
        set(true, forKey: marker)
    }
}
