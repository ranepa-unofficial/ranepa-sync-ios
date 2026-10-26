import SwiftUI

enum Links {
    static let repo = URL(string: "https://github.com/Qteb/ranepa-sync")!
    static let privacyRaw = URL(string: "https://raw.githubusercontent.com/Qteb/ranepa-sync/main/PRIVACY.md")!
    static let privacyCDN = URL(string: "https://cdn.jsdelivr.net/gh/Qteb/ranepa-sync@main/PRIVACY.md")!
}

/// Версия, справка, конфиденциальность и связь с разработчиком.
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] ?? "") (\(info?["CFBundleVersion"] ?? ""))"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 16))
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)
                    Text("Расписание студента").font(.title3.weight(.semibold))
                    Text("Версия \(version)").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                NavigationLink { LegendView() } label: {
                    Label { Text("Обозначения") } icon: { SettingsIcon("list.bullet", .indigo) }
                }
                NavigationLink { PrivacyView() } label: {
                    Label { Text("Конфиденциальность") } icon: { SettingsIcon("lock.fill", .blue) }
                }
            }
            // Ссылки, которые открываются вне приложения.
            Section {
                Button {
                    Analytics.signal("Support.opened")
                    openURL(SupportLink.url)
                } label: {
                    externalRow("Поддержка в Telegram", icon: SettingsIcon(logo: "Telegram"))
                }
                Link(destination: Links.repo) {
                    externalRow("Исходный код на GitHub",
                                icon: SettingsIcon(asset: "GitHub", Color(red: 0x1F / 255, green: 0x23 / 255, blue: 0x28 / 255)))
                }
            } footer: {
                // Контуры корпусов на карте — из OpenStreetMap (ODbL).
                Text("Неофициальное приложение. Не связано с РАНХиГС.\nКонтуры корпусов: © участники [OpenStreetMap](https://www.openstreetmap.org/copyright).")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("О приложении")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Analytics.screen("about") }
    }

    private func externalRow(_ title: String, icon: SettingsIcon) -> some View {
        HStack {
            Label { Text(title).foregroundStyle(Color(.label)) } icon: { icon }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

/// Справка: что значат цвета и как управлять приложением жестами.
struct LegendView: View {
    private let kinds: [(String, String, String?)] = [
        ("лекция", "Лекция", nil),
        ("семинар", "Семинар", "Практические занятия"),
        ("физкультура", "Физкультура", "Узнаётся по названию предмета"),
        ("лабораторная", "Лабораторная", nil),
        ("консультация", "Консультация", nil),
        ("экзамен", "Экзамен или зачёт", nil),
        ("", "Другое", nil),
    ]
    private let gestures = [
        ("arrow.down", "Потяни вниз", "Обновить расписание"),
        ("arrow.left.arrow.right", "Листай влево и вправо", "Другой день"),
        ("calendar", "Листай полосу с датами", "Другая неделя"),
        ("hand.point.up.left", "Нажми на пару", "Аудитория, преподаватель и почта"),
        ("doc.on.doc", "Удерживай строку", "Скопировать текст"),
        ("person.crop.circle", "Нажми на своё фото", "Настройки и выход из ЛК"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(kinds, id: \.1) { kind, title, subtitle in
                    Label {
                        VStack(alignment: .leading) {
                            Text(title)
                            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
                        }
                    } icon: {
                        SettingsIcon(kindSymbol(kind), kindColor(kind))
                    }
                }
            } header: {
                Text("Типы пар")
            } footer: {
                Text("Цвет полоски слева от пары совпадает с цветом иконки и типа в подписи. "
                     + "Те же иконки — на экране блокировки, в Dynamic Island и на часах.")
            }
            Section("В ленте") {
                LabeledContent { Text("Уже прошла") } label: { Text("Бледная пара").foregroundStyle(.secondary) }
                LabeledContent { Text("Отменена") } label: { Text("Зачёркнутая пара").strikethrough() }
            }
            Section("Жесты") {
                ForEach(gestures, id: \.1) { symbol, title, subtitle in
                    Label {
                        VStack(alignment: .leading) {
                            Text(title)
                            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: symbol).foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Обозначения")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Политика конфиденциальности: свежая версия из репозитория, без сети —
/// копия из приложения. Показывается русская часть, до `---`.
struct PrivacyView: View {
    @State private var blocks: [String]?

    var body: some View {
        ScrollView {
            if let blocks {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
                .padding(20)
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .navigationTitle("Конфиденциальность")
        .navigationBarTitleDisplayMode(.inline)
        .task { blocks = await Self.load() }
    }

    @ViewBuilder
    private func blockView(_ block: String) -> some View {
        if block.hasPrefix("## ") {
            Text(block.dropFirst(3)).font(.title3.weight(.semibold)).padding(.top, 10)
        } else if block.hasPrefix("- ") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(block.components(separatedBy: "\n- "), id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        inline(item.hasPrefix("- ") ? String(item.dropFirst(2)) : item)
                    }
                }
            }
        } else {
            inline(block)
        }
    }

    private func inline(_ markdown: String) -> Text {
        let text = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        return Text(text)
    }

    /// Блоки документа без заголовка первого уровня: он дублирует навбар.
    private static func load() async -> [String] {
        var text: String?
        for url in [Links.privacyRaw, Links.privacyCDN] {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                let body = String(decoding: data, as: UTF8.self)
                if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") { text = body; break }
            }
        }
        if text == nil, let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "md") {
            text = try? String(contentsOf: url, encoding: .utf8)
        }
        let russian = (text ?? "").components(separatedBy: "\n---").first ?? ""
        return russian
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("# ") }
    }
}
