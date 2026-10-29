import Observation
import StoreKit
import SwiftUI

/// Проверка новой версии. Манифест `update.json` лежит в корне этого
/// репозитория; как его обновлять при выпуске — в docs/release.md.
/// Своего сервера нет: файл качается с GitHub, запасной путь — jsDelivr.
@MainActor
@Observable
final class Updates {
    static let shared = Updates()

    enum Source: String {
        case appStore = "appstore"
        case testFlight = "testflight"
        /// Сборка из Xcode: обновлять нечего.
        case xcode
    }

    enum Status: Equatable {
        case none
        /// Есть новая версия — строка в аккаунте и точка на аватаре.
        case available(latest: String, notes: String?)
        /// Эта версия больше не работает — экран поверх всего приложения.
        case required
    }

    private(set) var status = Status.none
    private(set) var source = Source.xcode
    /// Точку на аватаре гасит открытие аккаунта, по разу на версию.
    private(set) var unseen = false
    /// Лист «Вышла версия»: при открытии приложения, после «Позже» — снова
    /// через 3 дня, о ещё более новой версии — сразу.
    var showSheet = false

    static let downloadInterval: TimeInterval = 3 * 3600
    static let sheetInterval: TimeInterval = 3 * 24 * 3600

    private let d = UserDefaults.standard
    private var checking = false

    static let manifestURLs = [
        URL(string: "https://raw.githubusercontent.com/ranepa-unofficial/ranepa-sync-ios/main/update.json")!,
        URL(string: "https://cdn.jsdelivr.net/gh/ranepa-unofficial/ranepa-sync-ios@main/update.json")!,
    ]

    /// Куда ведёт кнопка «Обновить»: туда же, откуда установлено приложение.
    var storeURL: URL {
        source == .testFlight
            ? URL(string: "https://testflight.apple.com/join/evTDn2DB")!
            : URL(string: "https://apps.apple.com/app/id6822034998")!
    }

    /// При каждом открытии приложения: решение по сохранённому манифесту
    /// сразу (так «нужно обновить» работает и без сети), загрузка — не чаще
    /// раза в 3 часа.
    func check() async {
        guard !checking, !Clock.screenshotMode, !Clock.recordingMode else { return }
        checking = true
        defer { checking = false }
        source = await Self.detectSource()
        guard source != .xcode else { return }
        apply(d.data(forKey: Keys.updateManifest))
        var due = d.time(Keys.updateCheckedAt).map { Date().timeIntervalSince($0) >= Self.downloadInterval } ?? true
        #if DEBUG
        if Self.debugManifest != nil { due = true }
        #endif
        if due, let data = await Self.download() {
            d.set(data, forKey: Keys.updateManifest)
            d.setTime(Date(), Keys.updateCheckedAt)
            apply(data)
        }
        offerSheet()
    }

    private func offerSheet() {
        guard case .available(let latest, _) = status else { return }
        let shownAt = d.time(Keys.updateSheetShownAt)
        let sameVersion = d.string(forKey: Keys.updateSheetVersion) == latest
        if sameVersion, let shownAt, Date().timeIntervalSince(shownAt) < Self.sheetInterval { return }
        d.set(latest, forKey: Keys.updateSheetVersion)
        d.setTime(Date(), Keys.updateSheetShownAt)
        showSheet = true
    }

    var storeName: String { source == .testFlight ? "TestFlight" : "App Store" }

    static var currentName: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func markSeen() {
        guard case .available(let latest, _) = status else { return }
        d.set(latest, forKey: Keys.updateSeen)
        unseen = false
    }

    private func apply(_ data: Data?) {
        guard let data, let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return }
        status = Self.status(manifest, source: source, current: .current)
        if case .available(let latest, _) = status {
            unseen = d.string(forKey: Keys.updateSeen) != latest
        } else {
            unseen = false
        }
    }

    // MARK: - Решение

    struct Manifest: Decodable {
        var appstore: Channel?
        var testflight: Channel?
    }

    /// Версии канала. Номер сборки важен только в TestFlight: там одна
    /// версия выходит несколькими сборками.
    struct Channel: Decodable {
        var latest: String
        var latestBuild: Int?
        var minimum: String
        var minimumBuild: Int?
        var notes: String?
    }

    struct Version: Comparable {
        var parts: [Int]
        var build: Int

        init(_ version: String, build: Int = 0) {
            parts = version.split(separator: ".").map { Int($0) ?? 0 }
            self.build = build
        }

        static var current: Version {
            let info = Bundle.main.infoDictionary
            return Version(info?["CFBundleShortVersionString"] as? String ?? "0",
                           build: Int(info?["CFBundleVersion"] as? String ?? "") ?? 0)
        }

        /// 2.2 и 2.2.0 — одна версия; сборка сравнивается последней.
        static func < (a: Version, b: Version) -> Bool {
            for i in 0..<max(a.parts.count, b.parts.count) {
                let x = i < a.parts.count ? a.parts[i] : 0
                let y = i < b.parts.count ? b.parts[i] : 0
                if x != y { return x < y }
            }
            return a.build < b.build
        }

        static func == (a: Version, b: Version) -> Bool { !(a < b) && !(b < a) }
    }

    static func status(_ manifest: Manifest, source: Source, current: Version) -> Status {
        let channel: Channel?
        switch source {
        case .appStore: channel = manifest.appstore
        case .testFlight: channel = manifest.testflight
        case .xcode: return .none
        }
        guard let channel else { return .none }
        // В App Store номер сборки пользователю не виден и не сравнивается.
        let withBuild = source == .testFlight
        let mine = withBuild ? current : Version(current.parts.map(String.init).joined(separator: "."))
        let minimum = Version(channel.minimum, build: withBuild ? channel.minimumBuild ?? 0 : 0)
        let latest = Version(channel.latest, build: withBuild ? channel.latestBuild ?? 0 : 0)
        if mine < minimum { return .required }
        if mine < latest {
            let name = withBuild && channel.latestBuild != nil
                ? "\(channel.latest) (\(channel.latestBuild!))" : channel.latest
            return .available(latest: name, notes: channel.notes)
        }
        return .none
    }

    // MARK: - Сеть и источник

    #if DEBUG
    /// Из аргументов напрямую: значение с «{» UserDefaults читает как словарь.
    private static var debugManifest: Data? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-UPDATE_MANIFEST"), i + 1 < args.count else { return nil }
        return Data(args[i + 1].utf8)
    }
    #endif

    private static func download() async -> Data? {
        #if DEBUG
        // Проверить экраны без GitHub: -UPDATE_MANIFEST '{"testflight": {...}}'
        if let debugManifest { return debugManifest }
        #endif
        for url in manifestURLs {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.timeoutInterval = 8
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200,
               (try? JSONDecoder().decode(Manifest.self, from: data)) != nil {
                return data
            }
        }
        return nil
    }

    /// TestFlight — песочница StoreKit, App Store — production.
    private static func detectSource() async -> Source {
        #if DEBUG
        // Проверить экраны обновления: -UPDATE_SOURCE testflight
        if let forced = UserDefaults.standard.string(forKey: "UPDATE_SOURCE"),
           let source = Source(rawValue: forced) { return source }
        return .xcode
        #else
        if let transaction = try? await AppTransaction.shared.payloadValue {
            switch transaction.environment {
            case .production: return .appStore
            case .sandbox: return .testFlight
            default: return .xcode
            }
        }
        // Без сети AppTransaction может не ответить — смотрим на чек.
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
        #endif
    }
}

/// «Нужно обновить» — поверх всего приложения, закрыть нельзя.
struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL
    let updates: Updates

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            AppIcon(size: 92)
            Text("Нужно обновить приложение")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 28)
            Text("Версия \(Updates.currentName) больше не работает с личным кабинетом. Расписание и настройки после обновления останутся.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Spacer()
            Spacer()
            Button { openURL(updates.storeURL) } label: {
                Text("Обновить в \(updates.storeName)").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Лист «Вышла версия»: смахнуть или «Позже» — вернётся через 3 дня.
struct UpdateSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let updates: Updates

    var body: some View {
        if case .available(let latest, let notes) = updates.status {
            ScrollView {
                VStack(spacing: 0) {
                    AppIcon(size: 76).padding(.top, 28)
                    Text("Вышла версия \(latest)")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    Text("У тебя \(Updates.currentName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    if let notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Что нового").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            Text(notes)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
                        .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        openURL(updates.storeURL)
                        dismiss()
                    } label: {
                        Text("Обновить в \(updates.storeName)").fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Button("Позже") { dismiss() }
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .presentationDetents([.fraction(0.66), .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        Image("Logo")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.22))
            .accessibilityHidden(true)
    }
}

/// Строка «Доступна версия» в аккаунте — пока не обновились.
struct UpdateRow: View {
    @Environment(\.openURL) private var openURL
    let updates: Updates

    var body: some View {
        if case .available(let latest, _) = updates.status {
            Section {
                Button { openURL(updates.storeURL) } label: {
                    HStack {
                        Label {
                            Text("Доступна версия \(latest)").foregroundStyle(Color(.label))
                        } icon: { SettingsIcon("arrow.down.circle.fill", .blue) }
                        Spacer()
                        Text("Обновить").foregroundStyle(.tint)
                    }
                }
            }
        }
    }
}
