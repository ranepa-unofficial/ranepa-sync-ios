import UIKit

/// Полная загрузка: месяц вперёд, то есть текущая неделя и ещё 4.
/// Делается первым обновлением за день.
let fetchWeeks = 5

/// Загрузка до конца семестра — при входе и раз в неделю. ЛК отдаёт
/// расписание вместе с сессией; 20 недель хватает на любой семестр.
let semesterWeeks = 20
/// Столько пустых недель подряд — значит, семестр кончился. Меньше нельзя:
/// перед сессией бывают каникулы на пару недель.
let emptyWeeksToStop = 4

/// Напоминание о паре по умолчанию, пока пользователь не выбрал своё.
let defaultReminderMinutes = 15

enum SyncTrigger {
    case background, open, manual
    /// Кнопка в отладке: без проверок интервалов и тихих часов.
    case debug
}

enum SkipReason {
    /// Пауза после ошибки сервера.
    case backoff
    /// С прошлого обновления прошло слишком мало времени.
    case tooSoon
    /// Обновлять нечего: каникулы или данные свежие.
    case notNeeded
    /// Сессия ЛК истекла — сначала войти заново.
    case needLogin
}

struct SyncResult {
    /// Изменения в ближайшие дни по сравнению с прошлой загрузкой.
    var changes: [String] = []
    var sideEffectError: String?
    /// Почему в ЛК не ходили; nil — обновление было.
    var skipped: SkipReason?
}

/// Когда и сколько загружать из ЛК.
enum Sync {
    /// При открытии не пытаемся чаще, даже если прошлая попытка не удалась.
    private static let openRetryAfter: TimeInterval = 15 * 60
    /// «Потянуть вниз» чаще этого не делает запросов.
    private static let manualCooldown: TimeInterval = 2 * 60
    /// Допуск к интервалу фона: система запускает задачу с разбросом.
    private static let intervalSlack: TimeInterval = 15 * 60
    /// Пауза после ответа 429/5xx: 8 → 16 → 24 часа.
    private static let backoffBase: TimeInterval = 4 * 3600
    private static let backoffMax: TimeInterval = 24 * 3600
    /// Фото весит под мегабайт — качаем его при входе и потом раз в неделю.
    private static let photoMaxAge: TimeInterval = 7 * 24 * 3600

    private static func since(_ d: UserDefaults, _ key: String, _ now: Date) -> TimeInterval {
        // Отметка из будущего (часы переводили назад) — считаем давней,
        // иначе обновления встанут до этой даты.
        d.time(key).map { now.timeIntervalSince($0) }.flatMap { $0 >= 0 ? $0 : nil } ?? 365 * 24 * 3600
    }

    /// Обновление стоит на паузе после ошибки сервера.
    static func paused(_ d: UserDefaults = .standard) -> Bool {
        d.time(Keys.backoffUntil).map { $0 > Clock.now } ?? false
    }

    /// Как часто фон ходит в ЛК в это время. Чаще всего — в учебное время,
    /// когда пары переносят и отменяют. Реже всего — ночью (раз в 4 часа)
    /// и в воскресенье днём (раз в 12): каждое обновление продлевает сессию
    /// ЛК, а она живёт сутки, так что совсем пропускать нельзя.
    static func interval(at now: Date) -> TimeInterval {
        let hour = now.hour
        if now.isoWeekday == 7 {
            // Вечером чаще: вдруг отменят первую пару понедельника.
            return hour >= 18 ? 3 * 3600 : 12 * 3600
        }
        if hour < 6 { return 4 * 3600 }
        // Вечером — реже, но изменения на завтра ловим.
        if hour >= 21 { return 3 * 3600 }
        return now.isoWeekday == 6 ? 2 * 3600 : 3600
    }

    /// На каникулах (пар в ближайшие 2 недели нет) — не чаще раза в 4 часа:
    /// обновлять нечего, но сессию ЛК продлевать надо.
    static let holidayInterval: TimeInterval = 4 * 3600

    /// Когда фону стоит проснуться: первый момент, когда с [now] прошло не
    /// меньше интервала, действующего в тот момент.
    static func nextRun(after now: Date) -> Date {
        var t = now
        for _ in 0..<(13 * 4) {
            t = t.addingTimeInterval(15 * 60)
            if t.timeIntervalSince(now) >= interval(at: t) { return t }
        }
        return t
    }

    /// Почему не надо идти в ЛК, или nil — надо. Отдельно от загрузки, чтобы
    /// проверять правила тестами.
    static func skipReason(_ d: UserDefaults, _ trigger: SyncTrigger, now: Date) -> SkipReason? {
        if let until = d.time(Keys.backoffUntil), until > now { return .backoff }
        // Без сессии страница ЛК всё равно уйдёт на вход: сами не ходим,
        // а «потянуть вниз» пробует — вдруг вошли в браузере.
        if d.bool(forKey: Keys.sessionExpired), trigger == .background || trigger == .open { return .needLogin }
        let full = isFullDue(d, now: now)
        switch trigger {
        case .background:
            let interval = lessonsSoon(d, now) ? interval(at: now) : max(interval(at: now), holidayInterval)
            if since(d, Keys.lastAttemptAt, now) < interval - intervalSlack { return .tooSoon }
        case .open:
            // Свежими считаем данные моложе интервала фона, но не старше 3 часов.
            let stale = min(interval(at: now), 3 * 3600)
            if since(d, Keys.fetchedAt, now) < stale || since(d, Keys.lastAttemptAt, now) < openRetryAfter {
                return .notNeeded
            }
        case .manual:
            if since(d, Keys.fetchedAt, now) < manualCooldown { return .tooSoon }
        case .debug:
            break
        }
        return nil
    }

    /// Первое обновление за день — полное.
    static func isFullDue(_ d: UserDefaults, now: Date) -> Bool {
        guard let last = d.time(Keys.lastFullAt) else { return true }
        return !last.sameDay(now)
    }

    /// Раз в неделю — весь семестр: дальние недели тоже меняются, но редко.
    static func isSemesterDue(_ d: UserDefaults, now: Date) -> Bool {
        since(d, Keys.lastSemesterAt, now) >= 7 * 24 * 3600
    }

    /// Решает, идти ли в ЛК и сколько грузить, и загружает расписание через
    /// невидимый WebView. Семестр — раз в неделю, месяц — первым обновлением
    /// за день, иначе текущую неделю (с пятницы — и следующую).
    @MainActor
    static func run(_ trigger: SyncTrigger, _ d: UserDefaults = .standard) async throws -> SyncResult {
        if d.bool(forKey: Keys.demo) { return await Demo.sync(trigger, d) }
        // Часы переведены для скриншотов: в ЛК не ходим, иначе загрузка
        // «из будущего» перепишет настоящее расписание.
        if Clock.screenshotMode { return SyncResult(skipped: .notNeeded) }
        let now = Clock.now
        if let reason = skipReason(d, trigger, now: now) { return SyncResult(skipped: reason) }

        let semester = isSemesterDue(d, now: now)
        let full = semester || isFullDue(d, now: now)
        d.setTime(now, Keys.lastAttemptAt)
        let monday = now.monday
        let weeks = semester ? semesterWeeks : full ? fetchWeeks : (now.isoWeekday >= 5 ? 2 : 1)
        let result: FetchResult
        do {
            result = try await LKWebView.refresh(monday: monday, weeks: weeks,
                                                 stopAfterEmpty: semester ? emptyWeeksToStop : nil,
                                                 withProfile: full, withPhoto: full && photoStale(d), withPlan: semester,
                                                 // Баллы — раз в день и по «потянуть вниз».
                                                 withProgress: full || trigger == .manual)
        } catch LKError.serverBusy(let status, let retryAfter) {
            startBackoff(d, retryAfter: retryAfter)
            throw LKError.serverBusy(status: status, retryAfter: retryAfter)
        }
        d.removeObject(forKey: Keys.backoffUntil)
        d.removeObject(forKey: Keys.backoffFailures)
        return await save(result, monday: monday, weeks: weeks, replaceAll: semester, d)
    }

    /// Есть ли пары в ближайшие 14 дней — если нет, это каникулы.
    private static func lessonsSoon(_ d: UserDefaults, _ now: Date) -> Bool {
        let until = now.adding(days: 14)
        return cachedLessons(d).contains { $0.end > now && $0.start < until }
    }

    private static func startBackoff(_ d: UserDefaults, retryAfter: Int?) {
        let failures = d.integer(forKey: Keys.backoffFailures) + 1
        var pause = min(backoffBase * Double(1 << failures), backoffMax)
        pause = max(pause, Double(retryAfter ?? 0))
        d.set(failures, forKey: Keys.backoffFailures)
        d.setTime(Clock.now.addingTimeInterval(pause), Keys.backoffUntil)
    }

    private static func photoStale(_ d: UserDefaults) -> Bool {
        d.time(Keys.photoFetchedAt).map { Clock.now.timeIntervalSince($0) > photoMaxAge } ?? true
    }

    /// data:image/png;base64,… → PNG 256×256 в base64 (несколько десятков КБ).
    private static func shrinkPhoto(_ dataURL: String) -> String? {
        guard let comma = dataURL.firstIndex(of: ",") else { return nil }
        // Сайт режет base64 переносами строк каждые 64 символа.
        let base64 = dataURL[dataURL.index(after: comma)...].filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: String(base64)), let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 256
        let scale = side / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return png.base64EncodedString()
    }

    /// Сохраняет загруженное расписание, сравнивает с прошлым и обновляет
    /// напоминания, виджет и календарь. Семестр (при входе и раз в неделю)
    /// заменяет всё расписание, остальные загрузки — только свои недели.
    @MainActor
    static func save(_ result: FetchResult, monday: Date, weeks: Int = semesterWeeks, replaceAll: Bool = true,
                     _ d: UserDefaults = .standard) async -> SyncResult {
        let full = weeks >= fetchWeeks
        let hadCache = d.object(forKey: Keys.days) != nil
        let before = cachedLessons(d)
        let days = replaceAll ? keepRecent(d, monday: monday) + result.days
                              : merge(d, fresh: result.days, monday: monday, weeks: weeks)
        let after = parseLessons(days)

        saveDays(days, d)
        if let group = result.group { d.set(group, forKey: Keys.group) }
        if let program = result.program { d.set(program, forKey: Keys.program) }
        if let name = result.fullName, !name.isEmpty { d.set(name, forKey: Keys.fullName) }
        if let photo = result.photo {
            // Битое фото — останутся инициалы, попробуем в следующий раз.
            if let small = photo.isEmpty ? nil : shrinkPhoto(photo) {
                d.set(small, forKey: Keys.photo)
            } else {
                d.removeObject(forKey: Keys.photo)
            }
            d.setTime(Clock.now, Keys.photoFetchedAt)
        }
        d.setTime(Clock.now, Keys.fetchedAt)
        if let until = result.sessionUntil { d.setTime(until, Keys.sessionUntil) }
        if let plan = result.plan { d.set(plan, forKey: Keys.plan) }
        let gradeChanges = saveProgress(result.progress, d)
        if full { d.setTime(Clock.now, Keys.lastFullAt) }
        if replaceAll {
            d.setTime(monday, Keys.rangeStart)
            d.setTime(Clock.now, Keys.lastSemesterAt)
        }
        d.set(true, forKey: Keys.loggedIn)
        d.removeObject(forKey: Keys.sessionExpiredNotified)
        d.removeObject(forKey: Keys.sessionExpired)

        if d.bool(forKey: Keys.gradeNotifications) { await Notifications.showGrades(gradeChanges) }
        return SyncResult(changes: hadCache ? describeChanges(before: before, after: after, now: Clock.now) : [],
                          sideEffectError: await applySideEffects(after, d))
    }

    /// Сохраняет успеваемость; возвращает изменившиеся баллы. Пустой ответ
    /// (ЛК не отдал блок) прошлые данные не стирает.
    static func saveProgress(_ raw: [String: Any]?, _ d: UserDefaults) -> [String] {
        guard let raw, let fresh = Progress(raw, at: Clock.now), !fresh.isEmpty else { return [] }
        let old = Progress.cached(d)
        fresh.save(d)
        return old.map { Progress.changes(from: $0, to: fresh) } ?? []
    }

    /// Сохранённые дни вне загруженных недель + свежие дни.
    /// Прошедшие дни за последние 60 дней: сданные зачёты и экзамены
    /// остаются в сессии, а пройденные пары — на экране предмета.
    private static func keepRecent(_ d: UserDefaults, monday: Date) -> [Any] {
        let from = monday.adding(days: -60)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return cachedDays(d).filter { day in
            let raw = "\((day as? [String: Any])?["date"] ?? "")"
            guard let date = f.date(from: String(raw.prefix(19))) else { return false }
            return date >= from && date < monday
        }
    }

    private static func merge(_ d: UserDefaults, fresh: [Any], monday: Date, weeks: Int) -> [Any] {
        let end = monday.adding(days: 7 * weeks)
        // Дата дня — без зоны, сравниваем как местную, как и раньше.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let kept = cachedDays(d).filter { day in
            let raw = "\((day as? [String: Any])?["date"] ?? "")"
            guard let date = f.date(from: String(raw.prefix(19))) else { return true }
            return date < monday || date >= end
        }
        return kept + fresh
    }

    /// Напоминания, виджет, Live Activity и календарь строятся из расписания.
    /// Возвращает текст ошибки или nil.
    @MainActor
    static func applySideEffects(_ lessons: [Lesson], _ d: UserDefaults = .standard) async -> String? {
        let minutes = d.object(forKey: Keys.reminderMinutes) == nil
            ? defaultReminderMinutes : d.integer(forKey: Keys.reminderMinutes)
        // Сначала активность: от её запуска по расписанию зависят напоминания.
        await LiveActivities.update(lessons, enabled: d.bool(Keys.liveActivity, default: true), reminderMinutes: minutes)
        await Notifications.scheduleReminders(lessons, minutes: minutes)
        await Notifications.scheduleExamReminders(lessons)
        // В демо сессии ЛК нет — напоминать о ней незачем.
        if let fetchedAt = d.time(Keys.fetchedAt), !d.bool(forKey: Keys.demo) {
            await Notifications.scheduleKeepAlive(lastSync: fetchedAt, sessionUntil: d.time(Keys.sessionUntil))
        }
        Outputs.update(lessons)
        guard d.bool(forKey: Keys.calendarExport) else { return nil }
        let from = d.time(Keys.rangeStart) ?? Clock.now.monday
        let last = lessons.map(\.start).max().map { $0.dateOnly.adding(days: 1) } ?? from
        return await CalendarExport.export(lessons, from: from, to: max(from.adding(days: 7 * fetchWeeks), last),
                                           reminderMinutes: minutes)
    }
}
