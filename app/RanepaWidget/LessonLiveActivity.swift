import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity: экран блокировки и Dynamic Island.
@available(iOS 16.2, *)
struct LessonLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivityAttributes.self) { context in
            let phase = Phase(context.state, stale: context.isStale)
            LockScreenView(phase: phase)
                .padding(14)
                .widgetURL(phase.lesson?.url)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let phase = Phase(context.state, stale: context.isStale)
            return DynamicIsland {
                // Всё в нижней области: боковые у «острова» узкие, таймер
                // в них не помещается. Раскладка та же, что на экране
                // блокировки: слева что, справа сколько, внизу — потом.
                DynamicIslandExpandedRegion(.bottom) {
                    if let change = context.state.change {
                        ChangeView(change: change).padding(.horizontal, 6)
                    } else {
                        LockScreenView(phase: phase).padding(.horizontal, 6)
                    }
                }
            } compactLeading: {
                if let lesson = phase.lesson {
                    HStack(spacing: 5) {
                        KindIcon(kind: lesson.kind, size: 14)
                        // Дистанционно — камера вместо номера аудитории.
                        if lesson.room == "Дистанционно" {
                            Image(systemName: "video.fill").font(.system(size: 13))
                        } else {
                            Text(lesson.compactRoom).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        }
                    }
                }
            } compactTrailing: {
                CountdownText(phase: phase)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(phase.lesson.map { kindColor($0.kind) } ?? .white)
                    .frame(maxWidth: 64)
            } minimal: {
                if let lesson = phase.lesson {
                    KindIcon(kind: lesson.kind, size: 15)
                } else {
                    Image(systemName: "calendar").foregroundStyle(liveAccent)
                }
            }
            .widgetURL(phase.lesson?.url)
        }
    }
}

private let liveAccent = Color(red: 0.90, green: 0.45, blue: 0.50)

/// Что показывать сейчас. Активность устаревает к концу идущей пары или
/// к началу ближайшей; если приложение не успело её обновить, следующий
/// шаг выводится отсюда.
@available(iOS 16.2, *)
private struct Phase {
    typealias Lesson = LessonActivityAttributes.Lesson

    /// Пара, о которой карточка: идущая или ближайшая.
    let lesson: Lesson?
    /// Идёт ли она.
    let ongoing: Bool
    /// Следующая после неё.
    let after: Lesson?

    init(_ state: LessonActivityAttributes.ContentState, stale: Bool) {
        switch (state.isCurrent, stale) {
        case (true, false):  // идёт пара
            lesson = state.lesson; ongoing = true; after = state.next
        case (true, true):   // пара закончилась — перемена или конец дня
            lesson = state.next; ongoing = false; after = nil
        case (false, false): // перемена до ближайшей
            lesson = state.lesson; ongoing = false; after = state.next
        case (false, true):  // ближайшая началась
            lesson = state.lesson; ongoing = true; after = state.next
        }
    }
}

/// Время окончания идущей пары или начала ближайшей. Не отсчёт: iOS
/// перерисовывает активность без приложения ненадёжно, и отсчёт после
/// конца пары застревал на «0:00». Время верно в любой момент.
@available(iOS 16.2, *)
private struct CountdownText: View {
    let phase: Phase

    var body: some View {
        if let lesson = phase.lesson {
            Text(hm(phase.ongoing ? lesson.end : lesson.start))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("")
        }
    }
}

/// Иконка типа в цветном круге — главный знак карточки.
@available(iOS 16.2, *)
private struct KindBadge: View {
    let kind: String
    let size: CGFloat

    var body: some View {
        Image(systemName: kindSymbol(kind))
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(kindColor(kind))
            .frame(width: size, height: size)
            .background(kindColor(kind).opacity(0.25), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Название пары и «Лекция · 5 - 201».
@available(iOS 16.2, *)
private struct TitleColumn: View {
    let phase: Phase
    let fullRoom: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let lesson = phase.lesson {
                Text(lesson.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text([capitalized(lesson.kind), fullRoom ? lesson.fullRoom : lesson.room]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("На сегодня всё").font(.system(size: 17, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// «до конца 54:12» / «начало через 1:15».
@available(iOS 16.2, *)
private struct TimerColumn: View {
    let phase: Phase

    var body: some View {
        if phase.lesson != nil {
            VStack(alignment: .trailing, spacing: 0) {
                Text(phase.ongoing ? "идёт до" : "начало в")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                CountdownText(phase: phase)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
        }
    }
}

/// Прогресс идущей пары (или тонкий разделитель) и строка «Потом …».
@available(iOS 16.2, *)
private struct FooterRows: View {
    let phase: Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = phase.lesson, phase.ongoing {
                ProgressView(timerInterval: lesson.start...lesson.end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(kindColor(lesson.kind))
            } else if phase.after != nil {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            }
            if let next = phase.after {
                HStack {
                    Text("Потом \(next.kind.isEmpty ? next.title.lowercased() : next.kind) · \(next.room)")
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(hm(next.start))
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
        }
    }
}

private func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

/// Остров раскрылся сам: «Аудитория изменилась, 2 - 2016 → 5 - 301».
@available(iOS 16.2, *)
private struct ChangeView: View {
    let change: LessonActivityAttributes.Change

    private var symbol: String {
        switch change.kind {
        case .room: "arrow.triangle.2.circlepath"
        case .time: "clock.arrow.circlepath"
        case .cancelled: "xmark"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.25), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(change.headline).font(.system(size: 17, weight: .semibold))
                    Text([capitalized(change.lesson.kind), change.lesson.title, hm(change.lesson.start)]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let old = change.old, let new = change.new {
                HStack(spacing: 10) {
                    Text(old).strikethrough().foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                        .accessibilityLabel("на")
                    Text(new).fontWeight(.semibold)
                }
                .font(.system(size: 17))
                .monospacedDigit()
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 18))
            }
        }
        .foregroundStyle(.white)
    }
}

@available(iOS 16.2, *)
private struct LockScreenView: View {
    let phase: Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let lesson = phase.lesson { KindBadge(kind: lesson.kind, size: 40) }
                TitleColumn(phase: phase, fullRoom: false)
                TimerColumn(phase: phase)
            }
            FooterRows(phase: phase)
        }
        .foregroundStyle(.white)
    }
}
