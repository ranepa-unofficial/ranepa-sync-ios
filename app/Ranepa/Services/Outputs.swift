import ActivityKit
import Foundation
import UIKit
import WatchConnectivity
import WidgetKit

/// Виджет, часы и Live Activity получают пары из приложения: сами в ЛК
/// они не ходят.
enum Outputs {
    private static func item(_ l: Lesson) -> LessonItem {
        LessonItem(s: l.start.timeIntervalSince1970, e: l.end.timeIntervalSince1970,
                   t: l.subject, k: l.kind, r: l.shortLocation, c: l.cancelled ? true : nil)
    }

    /// Для виджетов — ещё преподаватель, адрес и корпус в Картах: сами они
    /// не знают ни схемы кампуса, ни какие Карты установлены.
    @MainActor private static func widgetItem(_ l: Lesson) -> LessonItem {
        var item = item(l)
        item.l = l.lecturer.isEmpty ? nil : l.lecturer
        if !l.isRemote, let address = Places.address(from: l.room) {
            item.a = address
            let app = MapApp.preferred ?? .apple
            item.m = (Places.cachedLocation(address).map { app.url($0, name: l.mapTitle) }
                ?? app.url(search: Places.query(for: address))).absoluteString
        }
        return item
    }

    private static func json(_ items: [LessonItem]) -> String {
        (try? JSONEncoder().encode(items)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    /// Виджету — пары на две недели вперёд: какие показать «сейчас», он решает
    /// сам по часам. Часам — ещё прошедшие дни недели и отменённые пары: там
    /// можно листать неделю.
    @MainActor static func update(_ lessons: [Lesson]) {
        let now = Clock.now
        let horizon = now.adding(days: 14)
        // Отменённые тоже: виджет показывает их зачёркнутыми.
        let widget = lessons.filter { $0.end > now && $0.start < horizon }.map(widgetItem)
        let watch = lessons.filter { $0.start >= now.monday && $0.start < horizon }.map(item)
        let shared = UserDefaults(suiteName: appGroup)
        shared?.set(json(widget), forKey: SharedKeys.lessons)
        shared?.set(Clock.shift, forKey: SharedKeys.nowShift)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        WatchSync.shared.send(lessons: json(watch))
    }
}

/// Передаёт пары на Apple Watch тем же контекстом, что и Flutter-версия.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    private var pending: [String: Any]?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated { session.activate() }
    }

    func send(lessons: String) {
        send(["lessons": lessons, "nowShift": Clock.shift, "sentAt": Date().timeIntervalSince1970])
    }

    private func send(_ context: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pending = context
            return activate()
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(context)
        // Усложнение на циферблате: так часы обновят его сразу. У системы
        // на это дневной лимит.
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(context)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated, let context = pending else { return }
        pending = nil
        send(context)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    // Пользователь сменил часы — активируем сессию для новых.
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

/// Что Live Activity должна показывать сейчас. Без побочных эффектов —
/// для тестов.
struct LiveActivityPlan: Equatable {
    typealias A = LessonActivityAttributes
    /// Показываем, когда пара идёт или начнётся в эти 2 часа.
    static let lead: TimeInterval = 2 * 3600

    /// Пары оставшейся части дня; nil — активность сегодня не нужна.
    var today: A.ContentState?
    /// Запустить сейчас (если приложение открыто): пара идёт или скоро.
    var startNow = false
    /// Запуск по расписанию вместе с напоминанием о первой паре дня.
    var scheduled: Scheduled?

    struct Scheduled: Equatable {
        let state: A.ContentState
        let at: Date
    }

    /// [lessons] — по настоящим часам, отменённые уже убраны.
    /// [running] — активность уже идёт: держим её до конца дня.
    /// [reminderMinutes] — 0, если напоминания выключены: тогда без
    /// запуска по расписанию, только из открытого приложения.
    init(_ lessons: [A.Lesson], now: Date, running: Bool, reminderMinutes: Int) {
        let upcoming = lessons.filter { $0.end > now }.sorted { $0.start < $1.start }
        let todays = upcoming.filter { $0.start.sameDay(now) }
        if let first = todays.first {
            today = A.ContentState(lesson: first, next: todays.dropFirst().first, isCurrent: first.start <= now)
            startNow = !running && first.start.timeIntervalSince(now) <= Self.lead
        }
        let started = running || startNow
        // Сегодняшние пары ещё не начались — по расписанию запустится сегодня,
        // иначе — в следующий день с парами.
        let day = !todays.isEmpty && !started ? todays : {
            let later = upcoming.filter { !$0.start.sameDay(now) }
            return later.filter { $0.start.sameDay(later.first?.start ?? now) }
        }()
        if reminderMinutes > 0, let first = day.first {
            let at = first.start.addingTimeInterval(-Double(reminderMinutes) * 60)
            if at > now.addingTimeInterval(60) {
                scheduled = Scheduled(state: A.ContentState(lesson: first, next: day.dropFirst().first, isCurrent: false),
                                      at: at)
            }
        }
    }
}

/// Текст для часов и устройств без острова: «Философия, 12:20: 2 - 2016 → 5 - 301».
func changeBody(_ change: LessonActivityAttributes.Change) -> String {
    let head = "\(change.lesson.title), \(hm(change.lesson.start))"
    guard let old = change.old, let new = change.new else { return head }
    return "\(head): \(old) → \(new)"
}

extension LiveActivityPlan {
    /// Что поменялось у пар, которые сейчас в активности ([old]): другая
    /// аудитория, время или отмена. [lessons] — по настоящим часам, без
    /// отменённых. Закончившиеся пары не в счёт.
    static func change(from old: A.ContentState, to lessons: [A.Lesson], now: Date) -> A.Change? {
        let shown = [old.lesson] + (old.next.map { [$0] } ?? [])
        for was in shown where was.end > now {
            if lessons.contains(was) { continue }
            if let moved = lessons.first(where: { $0.title == was.title && $0.start == was.start }) {
                if moved.room != was.room {
                    return A.Change(kind: .room, lesson: was, old: was.room, new: moved.room)
                }
                continue
            }
            // Та же пара в другое время этого дня — если её не было в активности.
            let candidates = lessons.filter { l in
                l.title == was.title && l.start.sameDay(was.start) && !shown.contains { $0.start == l.start }
            }
            if let moved = candidates.min(by: { abs($0.start.timeIntervalSince(was.start)) < abs($1.start.timeIntervalSince(was.start)) }) {
                return A.Change(kind: .time, lesson: was, old: hm(was.start), new: hm(moved.start))
            }
            return A.Change(kind: .cancelled, lesson: was, old: nil, new: nil)
        }
        return nil
    }
}

/// Пара на экране блокировки и в Dynamic Island. Запустить активность iOS
/// разрешает только из открытого приложения (или по расписанию, о котором
/// попросили оттуда же), обновлять и завершать — и из фона.
enum LiveActivities {
    typealias A = LessonActivityAttributes

    /// Начало пары (по часам приложения), о которой напомнит запуск
    /// активности по расписанию: обычное напоминание о ней не нужно.
    static var scheduledLesson: Date? {
        Activity<A>.activities.first { $0.activityState == .pending }
            .map { $0.content.state.lesson.start.addingTimeInterval(Clock.shift) }
    }

    /// Когда закончится последняя пара дня, если активность сейчас видна:
    /// к этому времени фон должен её убрать.
    static func dayEnd(_ lessons: [Lesson]) -> Date? {
        guard Activity<A>.activities.contains(where: { [.active, .stale].contains($0.activityState) }) else { return nil }
        let now = Clock.now
        return lessons.filter { !$0.cancelled && $0.start.sameDay(now) }.map(\.end).max()?
            .addingTimeInterval(-Clock.shift)
    }

    static func update(_ lessons: [Lesson], enabled: Bool, reminderMinutes: Int) async {
        let source = enabled ? lessons.filter { !$0.cancelled } : []
        // Таймеры активности идут по настоящим часам — убираем сдвиг скриншотов.
        let real = source.map {
            A.Lesson(title: $0.subject, kind: $0.kind, room: $0.shortLocation, fullRoom: $0.location,
                     start: $0.start.addingTimeInterval(-Clock.shift), end: $0.end.addingTimeInterval(-Clock.shift))
        }
        let all = Activity<A>.activities
        let running = all.filter { [.active, .stale].contains($0.activityState) }
        let pending = all.filter { $0.activityState == .pending }
        let plan = LiveActivityPlan(real, now: Date(), running: !running.isEmpty, reminderMinutes: reminderMinutes)
        let active = await MainActor.run { UIApplication.shared.applicationState == .active }
        let canStart = active && ActivityAuthorizationInfo().areActivitiesEnabled

        // Сегодня.
        if var state = plan.today {
            if let current = running.first {
                // Пара в активности изменилась — остров раскрывается сам, со звуком.
                state.change = LiveActivityPlan.change(from: current.content.state, to: real, now: Date())
                let content = ActivityContent(state: state, staleDate: state.isCurrent ? state.lesson.end : state.lesson.start)
                // В открытом приложении об изменении скажет его баннер.
                if let change = state.change, !active {
                    let alert = AlertConfiguration(title: "\(change.headline)", body: "\(changeBody(change))", sound: .default)
                    await current.update(content, alertConfiguration: alert)
                } else {
                    await current.update(content)
                }
                for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
            } else if plan.startNow && canStart {
                let content = ActivityContent(state: state, staleDate: state.isCurrent ? state.lesson.end : state.lesson.start)
                _ = try? Activity<A>.request(attributes: A(), content: content)
            }
        } else {
            for a in running { await a.end(nil, dismissalPolicy: .immediate) }
        }

        // По расписанию. Запрос на будущее iOS тоже принимает только из
        // открытого приложения: из фона можно лишь отменить устаревший.
        let d = UserDefaults.standard
        let wanted = plan.scheduled
        let keep = pending.first { wanted?.state == $0.content.state && wanted?.at == d.time(Keys.liveActivityStartAt) }
        var changed = false
        for p in pending where p.id != keep?.id {
            await p.end(nil, dismissalPolicy: .immediate)
            changed = true
        }
        if keep == nil, let wanted, canStart, let lesson = source.first(where: {
            $0.start.addingTimeInterval(-Clock.shift) == wanted.state.lesson.start
        }) {
            let text = Notifications.reminderText(lesson, minutes: reminderMinutes)
            let alert = AlertConfiguration(title: "\(text.title)", body: "\(text.body)", sound: .default)
            if (try? Activity<A>.request(attributes: A(), content: ActivityContent(state: wanted.state, staleDate: wanted.state.lesson.start),
                                         style: .standard, alertConfiguration: alert, start: wanted.at)) != nil {
                d.setTime(wanted.at, Keys.liveActivityStartAt)
                changed = true
            }
        }
        // Напоминание о паре с запуском по расписанию — уже в нём.
        if changed { await Notifications.scheduleReminders(lessons, minutes: reminderMinutes) }
    }
}
