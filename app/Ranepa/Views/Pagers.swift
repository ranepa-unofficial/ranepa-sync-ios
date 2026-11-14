import SwiftUI

/// Название месяца листается пальцем, как в Календаре: соседний месяц
/// выезжает следом, полоса дней переходит к нему.
struct MonthPager: View {
    let months: [Date]
    let selected: Date
    let onSwipe: (Date) -> Void

    @State private var page: Int?
    /// Заголовок догоняет выбранный день: это не свайп пользователя.
    @State private var following = false

    private func index(of day: Date) -> Int {
        months.firstIndex { $0.year == day.year && $0.month == day.month } ?? 0
    }

    var body: some View {
        let now = Clock.now
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(months.indices, id: \.self) { i in
                    let m = months[i]
                    let name = monthsNominative[m.month - 1]
                    Text(m.year == now.year ? name : "\(name) \(m.year)")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .scrollClipDisabled(false)
        .clipHorizontally()
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { page = index(of: selected) }
        .onChange(of: selected) { _, day in
            let target = index(of: day)
            guard page != target else { return }
            following = true
            withAnimation(.smooth(duration: 0.3)) { page = target } completion: { following = false }
        }
        .onChange(of: page) { _, page in
            guard !following, let page, page != index(of: selected) else { return }
            onSwipe(months[page])
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monthsNominative[selected.month - 1])
        .accessibilityAddTraits(.isHeader)
    }
}

/// Полоса недель как в Календаре: листается неделями за пальцем, выбор
/// остаётся на том же дне недели. Если выбранный день ушёл в другую неделю
/// (листали пары, «Сегодня»), полоса перелистывается сама.
struct WeekPager: View {
    let selected: Date
    /// Понедельник первой недели.
    let firstDay: Date
    let weeks: Int
    let hasLessons: (Date) -> Bool
    let onSelect: (Date) -> Void

    @State private var page: Int?
    @State private var following = false

    private func week(of day: Date) -> Int { min(max(day.days(since: firstDay) / 7, 0), weeks - 1) }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<weeks, id: \.self) { w in
                    WeekRow(monday: firstDay.adding(days: w * 7), selected: selected,
                            hasLessons: hasLessons, onSelect: onSelect)
                        .padding(.horizontal, 8)
                        .containerRelativeFrame(.horizontal)
                        .id(w)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .clipHorizontally()
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { page = week(of: selected) }
        .onChange(of: selected) { _, day in
            let target = week(of: day)
            guard let current = page, current != target else { return }
            following = true
            if abs(target - current) > 1 {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { page = target > current ? target - 1 : target + 1 }
            }
            Task { @MainActor in
                withAnimation(.smooth(duration: 0.3)) { page = target } completion: { following = false }
            }
        }
        .onChange(of: page) { _, page in
            // Свайп недели: тот же день недели в новой неделе.
            guard !following, let page, page != week(of: selected) else { return }
            onSelect(firstDay.adding(days: page * 7 + selected.isoWeekday - 1))
        }
    }
}

/// Неделя: будни и выходные на общей подложке — видно, где кончается неделя.
private struct WeekRow: View {
    let monday: Date
    let selected: Date
    let hasLessons: (Date) -> Bool
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { cell($0) }
        }
        .background {
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: g.size.width * 2 / 7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }

    private func cell(_ i: Int) -> some View {
        let day = monday.adding(days: i)
        return DayCell(day: day, selected: day.sameDay(selected), dot: hasLessons(day)) { onSelect(day) }
            .frame(maxWidth: .infinity)
    }
}

private struct DayCell: View {
    let day: Date
    let selected: Bool
    let dot: Bool
    var showWeekday = true
    let action: () -> Void
    @ScaledMetric(relativeTo: .title3) private var size = 34

    var body: some View {
        let today = day.sameDay(Clock.now)
        let weekend = day.isoWeekday >= 6
        Button(action: action) {
            VStack(spacing: 4) {
                if showWeekday {
                    Text(weekdaysShort[day.isoWeekday - 1])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(day.day)")
                    .font(.title3.weight(selected || today ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(selected ? AnyShapeStyle(Color(.systemBackground))
                        : today ? AnyShapeStyle(.tint)
                        : weekend ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .frame(width: size, height: size)
                    .background {
                        if selected {
                            Circle().fill(today ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        }
                    }
                Circle()
                    .fill(dot ? Color(.systemGray2) : .clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(today ? "Сегодня, " : "")\(dayTitle(day))\(dot ? "" : ", пар нет")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Боковая панель iPad: все загруженные недели одной сеткой, как мини-
/// календарь. Выбранная неделя подсвечена, нажатие открывает день.
struct RangeCalendar: View {
    let selected: Date
    let firstDay: Date
    let weeks: Int
    let hasLessons: (Date) -> Bool
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(weekdaysShort, id: \.self) {
                        Text($0).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 4)
                ForEach(0..<weeks, id: \.self) { w in
                    let monday = firstDay.adding(days: w * 7)
                    // Название месяца над неделей, где он начинается.
                    if let first = (0..<7).map({ monday.adding(days: $0) }).first(where: { $0.day == 1 }) ?? (w == 0 ? monday : nil) {
                        Text(monthsNominative[first.month - 1])
                            .font(.headline)
                            .padding(.top, w == 0 ? 0 : 12)
                            .padding(.leading, 8)
                    }
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            let day = monday.adding(days: i)
                            DayCell(day: day, selected: day.sameDay(selected), dot: hasLessons(day),
                                    showWeekday: false) { onSelect(day) }
                        }
                    }
                    .background(monday.sameDay(selected.monday) ? Color(.tertiarySystemFill) : .clear,
                                in: .rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 12)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .navigationTitle("Расписание")
    }
}

/// iPad: выбранная неделя колонками карточек, над ней — «Сейчас».
struct WeekColumns: View {
    @Environment(AppState.self) private var state
    let week: Date
    /// Перерисовка раз в минуту: линия «сейчас» и «ещё N мин».
    let minute: Date
    let open: (Lesson) -> Void

    var body: some View {
        let days = (0..<7).map { week.adding(days: $0) }
            .filter { $0.isoWeekday < 7 || !state.lessons(on: $0).isEmpty }
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                ForEach(days, id: \.self) { day in
                    let lessons = state.lessons(on: day)
                    DayColumn(day: day, lessons: lessons, now: Clock.now,
                              next: lessons.last.flatMap { state.next(after: $0.end) }, open: open)
                }
            }
            .padding(20)
            .id(minute)
        }
        .refreshable { await state.refresh(.manual) }
    }
}

/// День колонкой карточек. Сегодня — с линией «сейчас», как в ленте iPhone:
/// до начала, в перерыве и после пар; у идущей пары — остаток и полоска.
private struct DayColumn: View {
    let day: Date
    let lessons: [Lesson]
    let now: Date
    let next: Lesson?
    let open: (Lesson) -> Void

    private func left(_ until: Date) -> String { durationText(until.timeIntervalSince(now) + 59) }

    var body: some View {
        let today = day.sameDay(now)
        let active = lessons.filter { !$0.cancelled }
        VStack(alignment: .leading, spacing: 8) {
            Text("\(weekdaysShort[day.isoWeekday - 1]), \(day.day)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(today ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            if lessons.isEmpty {
                Text("Пар нет").font(.footnote).foregroundStyle(.tertiary)
            }
            if today, let first = active.first, now < first.start {
                ColumnNowLine(now: now, caption: "Первая пара через \(left(first.start))")
            }
            ForEach(Array(lessons.enumerated()), id: \.element.id) { i, lesson in
                if today, i > 0, lessons[i - 1].end <= now, now < lesson.start,
                   !lessons[i - 1].cancelled, !lesson.cancelled {
                    let long = lesson.start.timeIntervalSince(lessons[i - 1].end) >= 3600
                    ColumnNowLine(now: now, caption: "\(long ? "Окно" : "Перерыв") · ещё \(left(lesson.start))")
                }
                card(lesson)
            }
            if today, let last = active.last, now >= last.end {
                ColumnNowLine(now: now, caption: "Пары закончились",
                              detail: next.map { "Следующая \(whenLabel($0.start))" })
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func card(_ lesson: Lesson) -> some View {
        let ongoing = lesson.isOngoing(at: now)
        return Button { open(lesson) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    KindIcon(kind: lesson.kind, size: 12)
                    Text("\(hm(lesson.start))–\(hm(lesson.end))")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                // Колонки узкие (iPad mini — около 100 pt): шрифт мельче,
                // чтобы длинные слова реже переносились по буквам.
                Text(lesson.subject)
                    .font(.footnote.weight(.semibold))
                    .strikethrough(lesson.cancelled)
                    .lineLimit(3)
                Text(lesson.isRemote ? "Дистанционно" : lesson.shortLocation)
                    .font(.caption).foregroundStyle(.secondary)
                if ongoing {
                    Text("ещё \(left(lesson.end))")
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                    ProgressView(value: min(max(now.timeIntervalSince(lesson.start)
                        / lesson.end.timeIntervalSince(lesson.start), 0), 1))
                        .tint(kindColor(lesson.kind))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            .opacity(lesson.cancelled || now > lesson.end ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }
}

/// Линия «сейчас» в колонке: время на красной плашке и подпись под ней.
private struct ColumnNowLine: View {
    let now: Date
    let caption: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text(hm(now))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red, in: .capsule)
                Rectangle().fill(Color.red).frame(height: 1.5)
            }
            Text(caption).font(.caption.weight(.semibold)).foregroundStyle(.red)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Обрезать по бокам, но не сверху и снизу. Горизонтальная прокрутка
    /// рисует соседние страницы под боковой safe area — на iPhone Duo там
    /// вертикальные панели и статус-бар. Сверху и снизу контент должен
    /// по-прежнему уходить под стеклянные шапку и таб-бар.
    func clipHorizontally() -> some View {
        clipShape(HorizontalClip())
    }
}

private struct HorizontalClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - 10_000, width: rect.width, height: rect.height + 20_000))
    }
}
