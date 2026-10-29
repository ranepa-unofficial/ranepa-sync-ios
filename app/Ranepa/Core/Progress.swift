import Foundation

/// Текущая успеваемость из ЛК (`dashboard/progress`): баллы БРС по предметам
/// текущего семестра, посещаемость по месяцам и средний балл.
struct Progress: Codable, Equatable {
    struct Subject: Codable, Equatable {
        /// Название как в расписании: «Иностранный язык».
        let name: String
        /// Баллы БРС, 0–100.
        let points: Int
    }

    struct Month: Codable, Equatable {
        /// «Октябрь».
        let name: String
        /// Сколько занятий было запланировано и сколько посещено.
        let plan: Int
        let fact: Int
    }

    var subjects: [Subject]
    var months: [Month]
    /// Средний балл из ЛК: по 100-балльной шкале и по 5-балльной. Строки
    /// вида «78» и «4,5»; nil — пока не было сессии.
    var averageBrs: String?
    var rating: String?
    var fetchedAt: Date

    var isEmpty: Bool { subjects.isEmpty && months.isEmpty }

    /// Ответ ЛК: `{brs: {labels, data}, visits: {items}, avg_brs, rating}`.
    init?(_ raw: [String: Any], at date: Date) {
        let brs = raw["brs"] as? [String: Any] ?? [:]
        let labels = brs["labels"] as? [Any] ?? []
        let values = brs["data"] as? [Any] ?? []
        var subjects: [Subject] = []
        for (i, label) in labels.enumerated() {
            let name = Self.subjectName("\(label)")
            guard !name.isEmpty, i < values.count, let points = Self.number(values[i]) else { continue }
            subjects.append(Subject(name: name, points: points))
        }
        let items = (raw["visits"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
        months = items.compactMap { m in
            guard let name = m["monthName"] as? String, let plan = Self.number(m["maxValue"]),
                  let fact = Self.number(m["currentValue"]) else { return nil }
            return Month(name: name, plan: plan, fact: fact)
        }
        self.subjects = subjects
        averageBrs = Self.text(raw["avg_brs"])
        rating = Self.text(raw["rating"])
        fetchedAt = date
    }

    /// «Иностранный язык_ОАФ_1 курс_B1-B2 [1 семестр] [Иванов И.И.] [группы]»
    /// → «Иностранный язык»: до первой скобки, без приписок через «_».
    static func subjectName(_ label: String) -> String {
        let head = label.components(separatedBy: " [").first ?? label
        let name = head.components(separatedBy: "_").first ?? head
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func points(for name: String) -> Int? {
        subjects.first { $0.name.lowercased() == name.lowercased() }?.points
    }

    /// Средний балл БРС по предметам — пока ЛК своего не считает.
    var averagePoints: Int? {
        guard !subjects.isEmpty else { return nil }
        return Int((Double(subjects.map(\.points).reduce(0, +)) / Double(subjects.count)).rounded())
    }

    /// Месяц посещаемости для карточки: последний, где уже что-то посещено.
    var currentMonth: Month? { months.last { $0.fact > 0 } }

    /// «Информатика: 16 → 24 балла» — для уведомления.
    static func changes(from old: Progress, to new: Progress) -> [String] {
        new.subjects.compactMap { s in
            guard let was = old.points(for: s.name), was != s.points else { return nil }
            return "\(s.name): \(was) → \(s.points) \(plural(s.points, "балл", "балла", "баллов"))"
        }
    }

    private static func number(_ value: Any?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        let s = (value as? NSNumber)?.stringValue ?? (value as? String)
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }

    // MARK: Хранение

    static func cached(_ d: UserDefaults = .standard) -> Progress? {
        d.data(forKey: Keys.progress).flatMap { try? JSONDecoder().decode(Progress.self, from: $0) }
    }

    func save(_ d: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { d.set(data, forKey: Keys.progress) }
        History.record(self, d)
    }
}

/// Баллы по дням за последние три недели: для «+4 за неделю».
enum History {
    struct Point: Codable { let day: Date; let points: Int }
    private static let keep: TimeInterval = 21 * 24 * 3600

    static func record(_ progress: Progress, _ d: UserDefaults) {
        var all = load(d)
        let day = progress.fetchedAt.dateOnly
        for s in progress.subjects {
            var list = all[s.name, default: []].filter { $0.day != day && $0.day > day.addingTimeInterval(-keep) }
            list.append(Point(day: day, points: s.points))
            all[s.name] = list.sorted { $0.day < $1.day }
        }
        if let data = try? JSONEncoder().encode(all) { d.set(data, forKey: Keys.progressHistory) }
    }

    /// Насколько изменились баллы за неделю; nil — нет записи недельной давности.
    static func weekDelta(_ name: String, now: Date, _ d: UserDefaults = .standard) -> Int? {
        let list = load(d)[name] ?? []
        let weekAgo = now.dateOnly.adding(days: -7)
        guard let base = list.last(where: { $0.day <= weekAgo }), let current = list.last else { return nil }
        return current.points - base.points
    }

    private static func load(_ d: UserDefaults) -> [String: [Point]] {
        d.data(forKey: Keys.progressHistory).flatMap { try? JSONDecoder().decode([String: [Point]].self, from: $0) } ?? [:]
    }
}
