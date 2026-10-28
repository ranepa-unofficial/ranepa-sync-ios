import Foundation
import TelemetryDeck
import WatchConnectivity
import WidgetKit

/// Анонимная статистика через TelemetryDeck: сколько человек пользуется
/// приложением и какие разделы открывают. Без логина, ФИО и группы: SDK
/// хэширует на устройстве случайный идентификатор установки. События те же,
/// что в Android-версии.
@MainActor
enum Analytics {
    /// App ID из project.yml (TELEMETRYDECK_APP_ID). Пустой — статистики нет.
    static let appID = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String ?? ""
    private static var started = false

    /// Выключена в демо и на скриншотах.
    static func allowed(_ d: UserDefaults = .standard) -> Bool {
        !appID.isEmpty && !d.bool(forKey: Keys.demo)
            && !Clock.screenshotMode && !Clock.recordingMode
    }

    /// Только из открытого приложения: SDK при запуске сразу начинает сессию,
    /// а фоновые пробуждения за пользователей не считаем.
    static func start() {
        guard !started, allowed() else { return }
        let config = TelemetryDeck.Config(appID: appID)
        #if DEBUG || TEST_TOOLS
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)
        started = true
    }

    static func stop() {
        guard started else { return }
        TelemetryDeck.terminate()
        started = false
    }

    static func signal(_ name: String, _ parameters: [String: String] = [:]) {
        guard started, allowed() else { return }
        TelemetryDeck.signal(name, parameters: parameters)
    }

    static func screen(_ name: String) { signal("Screen.opened", ["screen": name]) }

    /// Неудачное обновление на глазах у пользователя (не фон).
    static func syncFailed(_ error: Error, trigger: SyncTrigger) {
        signal("Sync.failed", ["reason": reason(error), "trigger": trigger == .manual ? "manual" : "open"])
    }

    nonisolated static func reason(_ error: Error) -> String {
        switch error {
        case LKError.needLogin: "session"
        case LKError.serverBusy: "server"
        case is URLError: "network"
        default: "other"
        }
    }

    /// Какие функции включены — раз в день, при открытии.
    static func daily(_ state: AppState) async {
        let d = UserDefaults.standard
        let now = Date()
        guard started, allowed(), dailyDue(last: d.time(Keys.analyticsDailyAt), now: now) else { return }
        d.setTime(now, Keys.analyticsDailyAt)
        let widgets = (try? await WidgetCenter.shared.currentConfigurations())?.isEmpty == false
        let watch = WCSession.isSupported() && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
        signal("Settings.daily", [
            "reminders": state.reminderMinutes > 0 ? String(state.reminderMinutes) : "off",
            "notifications": String(state.notificationsEnabled ?? false),
            "calendar": String(state.calendarExport),
            "liveActivity": String(state.liveActivity),
            "widgets": String(widgets),
            "watch": String(watch),
            "theme": ["auto", "light", "dark"][min(max(state.themeMode, 0), 2)],
        ])
    }

    /// Следующий календарный день по часам телефона.
    nonisolated static func dailyDue(last: Date?, now: Date) -> Bool {
        guard let last else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }
}
