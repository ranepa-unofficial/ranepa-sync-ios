import Foundation

/// Демо-режим: Наташа Ростова и выдуманное расписание без обращений к ЛК.
/// Нужен для App Review (у проверяющего нет аккаунта в ЛК), скриншотов
/// и проверки без интернета. Включается долгим нажатием на логотип
/// на стартовом экране.
enum Demo {
    static let group = "ГМУ-ОБ25-03"
    static let program = "Государственное и муниципальное управление"
    static let name = "Ростова Наталья Ильинична"

    /// Пары в ЛК: 09:00–10:20, 10:40–12:00, …
    private static let slots = [(9, 0), (10, 40), (12, 20), (14, 0), (15, 40)]
    private static let pairLength: TimeInterval = 80 * 60

    /// «Ускоренный день»: пары и перемены в минутах, а не в часах.
    static let fastLength: TimeInterval = 4 * 60
    static let fastBreak: TimeInterval = 2 * 60

    private static let lecture = "Лекция"
    private static let seminar = "Практическое занятие"
    private static let lab = "Лабораторная работа"

    private static let remote = "СДО (дистанционно)"
    private static let rooms = [
        "5 - 201 (44) П+ПК (Вернадского, 82 - корпус 5)",
        "1 - 1112 (20) ТВ+ПК Блок 1B (Вернадского, 84 - корпус 1)",
        "1 - 2262 (24) П+ПК Блок 2F (Вернадского, 84 - корпус 1)",
        "1 - 2317 (24) ТВ+ПК Блок 2H (Вернадского, 84 - корпус 1)",
        "Стадион (Вернадского, 82)",
    ]

    /// Предмет, преподаватель, почта. Люди и адреса выдуманы.
    private static let subjects = [
        ("Теория управления", "Соколова Мария Андреевна", "sokolova-ma"),
        ("Экономическая теория", "Лебедев Игорь Павлович", "lebedev-ip"),
        // Без почты: так тоже бывает, и карточка выглядит чище на скриншотах.
        ("Иностранный язык (английский)", "Морозова Ксения Олеговна", ""),
        ("Элективные дисциплины по физической культуре и спорту", "Васильев Денис Сергеевич", "vasilev-ds"),
        ("Математика", "Ершова Наталья Викторовна", "ershova-nv"),
        ("Основы российской государственности", "Кузнецов Алексей Михайлович", "kuznetsov-am"),
        ("Информационные технологии в управлении", "Тихонов Павел Андреевич", "tikhonov-pa"),
        ("Правоведение", "Белова Ольга Николаевна", "belova-on"),
    ]

    /// Неделя: день (1 — понедельник) → (пара, предмет, тип, аудитория).
    /// Аудитория -1 — дистанционно.
    private static let week: [Int: [(Int, Int, String, Int)]] = [
        1: [(0, 5, lecture, -1), (1, 1, lecture, 0), (2, 1, seminar, 2)],
        2: [(0, 0, lecture, 0), (1, 2, seminar, 3), (2, 3, seminar, 4), (3, 6, lab, 1)],
        3: [(1, 4, lecture, 0), (2, 4, seminar, 2), (3, 7, seminar, 3)],
        4: [(0, 7, lecture, -1), (1, 0, seminar, 1), (2, 2, seminar, 3)],
        5: [(0, 6, lecture, 0), (1, 1, seminar, 2), (2, 3, seminar, 4)],
        6: [(0, 5, seminar, -1), (1, 4, seminar, 1)],
    ]

    /// Сдвиг сегодняшних пар: вторая идёт уже 25 минут, поэтому карточка
    /// «Сейчас» видна в любое время. Кратен 5 минутам и не выходит за сутки.
    static func todayShift(_ now: Date) -> TimeInterval {
        let today = now.dateOnly
        let secondStart = today.addingTimeInterval(10 * 3600 + 40 * 60)
        var shift = now.timeIntervalSince(secondStart) - 25 * 60
        shift = (shift / 300).rounded() * 300
        // Отступ в 5 минут от полуночи с обеих сторон.
        let dayStart = today.addingTimeInterval(5 * 60)
        let firstStart = today.addingTimeInterval(9 * 3600 + shift)
        if firstStart < dayStart { shift += dayStart.timeIntervalSince(firstStart) }
        let lastEnd = today.addingTimeInterval(14 * 3600 + pairLength + shift)
        let dayEnd = today.addingTimeInterval(23 * 3600 + 55 * 60)
        if lastEnd > dayEnd { shift -= lastEnd.timeIntervalSince(dayEnd) }
        return shift
    }

    /// Расписание на [fetchWeeks] недель вокруг [now]. Сегодня — со сдвигом
    /// [shift] (в воскресенье — расписание вторника). Нечётная [revision] меняет
    /// аудиторию первой пары завтра — так видно уведомление об изменении.
    /// [fastFrom] — «ускоренный день»: сегодня пары по 4 минуты.
    static func result(now: Date, revision: Int = 0, shift: TimeInterval? = nil, fastFrom: Date? = nil) -> FetchResult {
        let today = now.dateOnly
        let monday = now.monday
        let shift = shift ?? todayShift(now)
        var nextDay = today.adding(days: 1)
        if nextDay.isoWeekday == 7 { nextDay = nextDay.adding(days: 1) }

        var days: [Any] = []
        for i in 0..<(7 * fetchWeeks) {
            let day = monday.adding(days: i)
            let isToday = day.sameDay(today)
            let plan = isToday && day.isoWeekday == 7 ? week[2]! : week[day.isoWeekday] ?? []
            let weekIndex = i / 7
            var discs: [[String: Any]] = []
            for (n, (slot, subject, type, room)) in plan.enumerated() {
                let (h, m) = slots[slot]
                var start = day.addingTimeInterval(Double(h * 3600 + m * 60))
                var length = pairLength
                if isToday, let fastFrom {
                    start = fastFrom.addingTimeInterval(Double(n) * (fastLength + fastBreak))
                    length = fastLength
                } else if isToday {
                    start = start.addingTimeInterval(shift)
                }
                // Зачёт — по правоведению: по математике в плане экзамен.
                let credit = day.isoWeekday == 6 && n == 1 && weekIndex == fetchWeeks - 2
                let (name, lecturer, email) = subjects[credit ? 7 : subject]
                var place = room < 0 ? remote : rooms[room]
                if revision % 2 == 1 && day.sameDay(nextDay) && n == 0 { place = rooms[(room + 2) % 4] }
                // Сессия по субботам: консультация, зачёт и экзамен. Зачёт —
                // не дальше месяца, чтобы карточка сессии была видна всегда.
                let session = day.isoWeekday == 6 && n == 1
                let kind = session && weekIndex == fetchWeeks - 3 ? "Консультация"
                    : session && weekIndex == fetchWeeks - 2 ? "Зачёт"
                    : session && weekIndex == fetchWeeks - 1 ? "Экзамен" : type
                discs.append([
                    "start_date": moscowStamp(start),
                    "end_date": moscowStamp(start.addingTimeInterval(length)),
                    "disc": name,
                    "type": kind,
                    "room": place,
                    "lecturer": lecturer,
                    "sam_email": email.isEmpty ? "" : "\(email)@ranepa.example",
                    "groups": type == lecture ? ["0": group, "1": "ГМУ-ОБ25-04"] : ["0": group],
                    "lms_link": room < 0 ? "https://lms.ranepa.ru/" : "",
                    "comment": type == lab ? "Нужен ноутбук" : "",
                    // Одна отменённая пара послезавтра.
                    "status": day.sameDay(nextDay.adding(days: 1)) && n == plan.count - 1 ? "Отменено" : "",
                ])
            }
            days.append(["date": moscowStamp(day), "discs": discs])
        }
        return FetchResult(days: days, group: group, program: program, fullName: name,
                           plan: plan(monday: monday), progress: progress(now: now, revision: revision))
    }

    /// Успеваемость в формате ЛК: метки дисциплин с приписками, как на сайте.
    /// Каждое «потянуть вниз» добавляет баллы по математике — видно
    /// уведомление о новых баллах.
    static func progress(now: Date, revision: Int = 0) -> [String: Any] {
        let points = [34, 41, 28, 55, 22 + 4 * revision, 37, 46, 31]
        let labels = subjects.enumerated().map { i, s in
            i == 2 ? "\(s.0)_ОАФ_1 курс_B1-B2 [1 семестр] [] []" : "\(s.0) [1 семестр] [] []"
        }
        // Семестр с сентября по январь; прошедшие месяцы посещены почти все.
        let names = ["Сентябрь", "Октябрь", "Ноябрь", "Декабрь", "Январь"]
        let plans = [63, 77, 63, 50, 5]
        let current = [9: 0, 10: 1, 11: 2, 12: 3, 1: 4][now.month] ?? 4
        let visits = names.indices.map { i -> [String: Any] in
            let fact = i < current ? plans[i] * 9 / 10 : i == current ? plans[i] * 2 / 3 * now.day / 30 : 0
            return ["monthName": names[i], "maxValue": plans[i], "currentValue": fact]
        }
        return ["brs": ["labels": labels, "data": points.map { min($0, 100) }],
                "visits": ["items": visits], "avg_brs": NSNull(), "rating": NSNull()]
    }

    /// План обучения: формы контроля по предметам и сессия — те две недели,
    /// где в демо стоят консультация, зачёт и экзамен.
    static func plan(monday: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd.MM.yyyy"
        let start = monday.adding(days: 7 * (fetchWeeks - 2))
        let next = start.adding(days: 7 * 22)
        func item(_ name: String, _ control: String?, _ hours: Int, semester: Int = 1) -> [String: Any] {
            var i: [String: Any] = ["name": name, "hours": hours, "ze": hours / 36, "course": 1,
                                    "semester": "\(semester)-й семестр", "elective": false, "practice": false,
                                    "courseWork": false, "facultative": false, "selected": true]
            if let control { i["control"] = control }
            return i
        }
        let current: [(String, String?, Int)] = [
            ("Математика", "Экзамен", 144), ("Экономическая теория", "Экзамен", 144),
            ("Теория управления", "Зачет", 72), ("Иностранный язык (английский)", "Зачет", 108),
            ("Основы российской государственности", "Зачет", 72), ("Информационные технологии в управлении", "Зачет с оценкой", 108),
            ("Правоведение", "Зачет", 72), ("Элективные дисциплины по физической культуре и спорту", nil, 64),
        ]
        let second: [(String, String?, Int)] = [
            ("Математика", "Экзамен", 144), ("Макроэкономика", "Экзамен", 144), ("Философия", "Зачет", 72),
            ("Иностранный язык (английский)", "Зачет", 108), ("Менеджмент", "Зачет с оценкой", 108),
        ]
        let plan: [String: Any] = [
            "items": current.map { item($0.0, $0.1, $0.2) } + second.map { item($0.0, $0.1, $0.2, semester: 2) },
            "sessions": [
                ["course": "1-й курс", "semester": "1-й семестр", "start": f.string(from: start),
                 "end": f.string(from: start.adding(days: 13))],
                ["course": "1-й курс", "semester": "2-й семестр", "start": f.string(from: next),
                 "end": f.string(from: next.adding(days: 13))],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: plan)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// Демо-расписание на сегодня. Сдвиг запоминается на весь день, иначе
    /// каждое обновление «переносило» бы сегодняшние пары.
    static func fetch(_ d: UserDefaults, revision: Int = 0) -> FetchResult {
        let now = Clock.now
        let day = "\(Int(now.dateOnly.timeIntervalSince1970))"
        let saved = d.string(forKey: Keys.demoShift)?.split(separator: "|")
        let shift: TimeInterval
        if Clock.screenshotMode {
            // Скриншоты: обычная сетка пар, состояние дня задаёт DEMO_AT.
            shift = 0
        } else if let saved, saved.count == 2, saved[0] == day, let minutes = Double(saved[1]) {
            shift = minutes * 60
        } else {
            shift = todayShift(now)
            d.set("\(day)|\(Int(shift / 60))", forKey: Keys.demoShift)
        }
        return result(now: now, revision: revision, shift: shift, fastFrom: d.time(Keys.demoFastFrom))
    }

    /// Обновление в демо: без сети. Расписание пересобирается раз в день,
    /// «потянуть вниз» каждый раз меняет одну аудиторию.
    @MainActor
    static func sync(_ trigger: SyncTrigger, _ d: UserDefaults) async -> SyncResult {
        let now = Clock.now
        let fresh = d.time(Keys.fetchedAt).map { $0.sameDay(now) } ?? false
        if trigger != .manual && fresh { return SyncResult(skipped: .notNeeded) }
        var revision = d.integer(forKey: Keys.demoRevision)
        if trigger == .manual {
            // Как настоящий запрос: жест не должен заканчиваться мгновенно.
            try? await Task.sleep(for: .milliseconds(800))
            revision += 1
            d.set(revision, forKey: Keys.demoRevision)
        }
        let result = await Sync.save(fetch(d, revision: revision), monday: now.monday, d)
        // Новый день пересобирает всё — это не изменения в расписании.
        return trigger == .manual ? result : SyncResult(sideEffectError: result.sideEffectError)
    }
}
