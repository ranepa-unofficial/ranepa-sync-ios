import SwiftUI
import TipKit
import UserNotifications

@main
struct RanepaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var state = AppState()

    init() {
        WatchSync.shared.activate()
        if Clock.screenshotMode || Clock.recordingMode { Tips.hideAllTipsForTesting() }
        try? Tips.configure()
        // Подсказки, закрытые во Flutter-версии, не показываем снова.
        let d = UserDefaults.standard
        d.migrateFromFlutter()
        if d.bool(forKey: "tip.refresh") { RefreshTip().invalidate(reason: .actionPerformed) }
        if d.bool(forKey: "tip.account") { AccountTip().invalidate(reason: .actionPerformed) }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if state.loggedIn {
                    RootView()
                } else {
                    AuthFlow()
                }
            }
            .environment(state)
            // Эта версия больше не работает — поверх всего, и до входа тоже.
            .overlay {
                if Updates.shared.status == .required {
                    UpdateRequiredView(updates: Updates.shared)
                }
            }
            .sheet(isPresented: Bindable(Updates.shared).showSheet) {
                UpdateSheet(updates: Updates.shared)
            }
            // Вход не удался — и со стартового экрана, и из листа повторного входа.
            .alert(state.loginFailure?.title ?? "", isPresented: Binding(
                get: { state.loginFailure != nil },
                set: { if !$0 { state.loginFailure = nil } }
            ), presenting: state.loginFailure) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                Text(failure.message)
            }
            // Крупный шрифт из настроек iOS, но не самый большой: дальше
            // названия пар рвутся по слогам на каждой строке.
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .animation(.default, value: state.loggedIn)
            .onAppear {
                delegate.state = state
                state.applyTheme()
                // Задача могла не зарегистрироваться (обновление со старой версии).
                if state.loggedIn && !state.demo { Background.schedule() }
            }
            .modifier(OnActive {
                Analytics.start()
                Task { await Analytics.daily(state) }
                Task { await Updates.shared.check() }
            })
            // ranepa://lesson?start=<секунды по настоящим часам> — из Live
            // Activity и виджета, ranepa://today — из Пункта управления.
            .onOpenURL { url in
                if url.host == "today" { return state.pendingToday = true }
                guard url.host == "lesson",
                      let start = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "start" })?.value.flatMap(Double.init)
                else { return }
                state.pendingLesson = Date(timeIntervalSince1970: start).addingTimeInterval(Clock.shift)
            }
        }
        .backgroundTask(.appRefresh(Background.taskID)) {
            await Background.run()
        }
    }
}

/// Каждый раз, когда приложение становится активным. scenePhase читаем здесь,
/// внутри окна: @Environment в самой структуре App пересоздаёт сцену, и SwiftUI
/// теряет AccentColor из ассетов — всё становится системно-синим.
private struct OnActive: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { action() }
        }
    }
}

/// Уведомления: показывать и в открытом приложении, по нажатию — открыть пару.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor var state: AppState?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let start = Notifications.lessonStart(response.notification.request.content.userInfo) else { return }
        // При холодном старте состояние ещё не создано — ждём его.
        Task { @MainActor in
            while state == nil { try? await Task.sleep(for: .milliseconds(50)) }
            state?.pendingLesson = start
        }
    }
}
