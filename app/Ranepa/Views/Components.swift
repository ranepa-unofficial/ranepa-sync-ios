import SwiftUI
import TipKit
import WidgetKit

/// Подпись типа пары: в светлой теме темнее системного цвета, чтобы
/// читалась на светлом фоне. Полоска и иконка — системный цвет
/// (kindColor в Shared/Lessons.swift).
func kindTextColor(_ kind: String) -> Color {
    let (light, dark): (UInt32, UInt32) = switch kind {
    case "лекция": (0x0062CC, 0x409CFF)
    case "семинар": (0x248A3D, 0x30D158)
    case "физкультура": (0xC93400, 0xFF9F0A)
    case "лабораторная": (0x8944AB, 0xDA8FFF)
    case "консультация": (0x0071A4, 0x5DE6FF)
    case "экзамен", "зачёт": (0xD30F45, 0xFF6482)
    default: (0x6C6C70, 0xAEAEB2)
    }
    func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
}

/// «Лекция · 5 - 201»: тип цветом типа (с иконкой — в ленте), остальное серым.
func lessonDetails(_ l: Lesson, icon: Bool = false) -> Text {
    let rest = [l.location.isEmpty ? "" : (l.isRemote ? "дистанционно" : l.shortLocation),
                l.cancelled ? "отменена" : ""]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    guard !l.kind.isEmpty else { return Text(rest) }
    // Иконка чуть мельче текста, как символы в подписях системных приложений.
    let kind = icon
        ? Text("\(Text(Image(systemName: kindSymbol(l.kind))).font(.caption)) \(l.kind.capitalizedFirst)")
        : Text(l.kind.capitalizedFirst)
    return Text("\(kind.foregroundStyle(kindTextColor(l.kind)))\(rest.isEmpty ? "" : " · ")\(rest)")
}

/// Цветная плашка с иконкой, как в «Настройках» iPhone.
struct SettingsIcon: View {
    private let symbol: String?
    private let asset: String?
    private let logo: String?
    let color: Color

    init(_ symbol: String, _ color: Color) {
        self.symbol = symbol
        asset = nil
        logo = nil
        self.color = color
    }

    /// Значок из каталога ресурсов, например логотип GitHub.
    init(asset: String, _ color: Color) {
        symbol = nil
        self.asset = asset
        logo = nil
        self.color = color
    }

    /// Логотип в оригинальных цветах и форме, без подложки, например Telegram или иконка приложения.
    init(logo: String) {
        symbol = nil
        asset = nil
        self.logo = logo
        color = .clear
    }

    var body: some View {
        if let logo {
            Image(logo).resizable().scaledToFit().frame(width: 30, height: 30)
                .clipShape(.rect(cornerRadius: 7))
        } else {
            tile
        }
    }

    private var tile: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
            } else if let asset {
                Image(asset).resizable().scaledToFit().frame(width: 19, height: 19)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(color.gradient, in: .rect(cornerRadius: 8))
    }
}

/// Фото из ЛК, а если его нет — инициалы «Имя Фамилия» на сером круге,
/// как у контактов. В демо — схематичный портрет.
struct AvatarView: View {
    @Environment(AppState.self) private var state
    let size: CGFloat

    private var initials: String {
        let parts = (state.fullName ?? "").split(separator: " ")
        guard parts.count >= 2 else { return "" }
        return "\(parts[1].prefix(1))\(parts[0].prefix(1))"
    }

    var body: some View {
        Group {
            if let photo = state.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else if state.demo {
                Image("DemoAvatar").resizable().scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray4)
                    if initials.isEmpty {
                        Image(systemName: "person.fill").font(.system(size: size * 0.5))
                    } else {
                        Text(initials).font(.system(size: size * 0.38, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Баннер сверху экрана: изменения в расписании или ошибка обновления.
struct Banner: Equatable {
    var title: String
    var message: String
    var symbol: String
}

struct BannerView: View {
    let banner: Banner

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: banner.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.subheadline.weight(.semibold))
                Text(banner.message).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Подсказки (TipKit)

struct RefreshTip: Tip {
    var title: Text { Text("Потяни вниз, чтобы обновить") }
    var message: Text? { Text("Расписание и так обновляется само в фоне, но так можно проверить изменения прямо сейчас.") }
    var image: Image? { Image(systemName: "arrow.down.circle") }
}

struct AccountTip: Tip {
    var title: Text { Text("Настройки — под фото") }
    var message: Text? { Text("Нажми на своё фото: там напоминания, календарь и выход из ЛК.") }
    var image: Image? { Image(systemName: "person.crop.circle") }
}

/// Через несколько дней пользования: про виджеты без подсказки мало кто узнаёт.
struct WidgetTip: Tip {
    /// Приложение открыли в новый день — считаем дни, а не запуски.
    static let openedOnDay = Tips.Event(id: "openedOnDay")

    var title: Text { Text("Добавь виджет") }
    var message: Text? {
        Text("Следующая пара будет видна на главном экране и экране блокировки. Долгое нажатие на пустое место → «+» → «Расписание».")
    }
    var image: Image? { Image(systemName: "square.grid.2x2") }

    var rules: [Rule] {
        #Rule(Self.openedOnDay) { $0.donations.count >= 3 }
    }

    /// Раз в день отмечает, что приложением пользуются, и прячет подсказку
    /// навсегда, если виджет уже стоит.
    @MainActor
    static func update() async {
        let d = UserDefaults.standard
        let today = Clock.now.dateOnly
        if d.time("tip.widget.day").map({ !$0.sameDay(today) }) ?? true {
            d.setTime(today, "tip.widget.day")
            await openedOnDay.donate()
        }
        if let widgets = try? await WidgetCenter.shared.currentConfigurations(), !widgets.isEmpty {
            WidgetTip().invalidate(reason: .actionPerformed)
        }
    }
}

/// Открывает письмо; если почтового приложения нет (его можно удалить),
/// копирует адрес, чтобы написать из другого.
@MainActor
func openMail(_ address: String, subject: String? = nil, openURL: OpenURLAction, copied: @escaping () -> Void) {
    var parts = URLComponents()
    parts.scheme = "mailto"
    parts.path = address
    if let subject { parts.queryItems = [URLQueryItem(name: "subject", value: subject)] }
    guard let url = parts.url else { return }
    openURL(url) { accepted in
        guard !accepted else { return }
        UIPasteboard.general.string = address
        copied()
    }
}

/// Шапка вкладки как у расписания: крупный заголовок и аватар в одной
/// строке, под ними подзаголовок. Ставится в `safeAreaBar(edge: .top)`.
/// Сессия ЛК истекла: расписание из кэша может быть устаревшим.
struct SessionExpiredCard: View {
    let login: () -> Void
    let later: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.orange))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Расписание может быть устаревшим").font(.headline)
                    Text("Сессия личного кабинета истекла, обновить расписание не получается.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Button("Войти", action: login)
                    .buttonStyle(.glassProminent)
                Button("Позже", action: later)
                    .buttonStyle(.glass)
            }
            .padding(.leading, 58)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }
}

struct TabHeader: View {
    let title: String
    var subtitle: String? = nil
    let openAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                AccountButton(action: openAccount)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// Фото в шапке — открывает настройки.
struct AccountButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            AccountTip().invalidate(reason: .actionPerformed)
            action()
        } label: {
            AvatarView(size: 36)
                // Новая версия, которую ещё не видели в аккаунте.
                .overlay(alignment: .topTrailing) {
                    if Updates.shared.unseen {
                        Circle()
                            .fill(.red)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Updates.shared.unseen ? "Аккаунт и настройки, доступна новая версия" : "Аккаунт и настройки")
    }
}

/// Пара в списке — везде одинаково: полоска цвета типа, когда (серым),
/// предмет, тип и аудитория. Прошедшая — бледнее.
struct LessonListRow: View {
    let lesson: Lesson
    /// День перед временем — когда список не разбит по дням.
    var showDay = true
    /// Предмет — не нужен на экране самого предмета.
    var showSubject = true
    /// Строка под всем, например консультация к экзамену.
    var note: String? = nil

    var body: some View {
        let past = lesson.end < Clock.now
        HStack(alignment: .top, spacing: 12) {
            KindStripe(kind: lesson.kind)
            VStack(alignment: .leading, spacing: 3) {
                Text(showDay ? "\(dayName(lesson.start)), \(hm(lesson.start))–\(hm(lesson.end))"
                             : "\(hm(lesson.start))–\(hm(lesson.end))")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if showSubject {
                    Text(lesson.subject).font(.headline).strikethrough(lesson.cancelled)
                }
                lessonDetails(lesson, icon: true).font(.subheadline).foregroundStyle(.secondary)
                if let note {
                    Text(note).font(.footnote).foregroundStyle(.secondary).padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        .opacity(past || lesson.cancelled ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }
}
