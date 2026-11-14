import SwiftUI
import TipKit

/// Главный экран как Календарь iPhone: месяц, «Сегодня» и аватар в одну
/// строку, под ними полоса недель, ниже лента пар выбранного дня.
/// На iPad вместо ленты — неделя колонками.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selected = Clock.now.dateOnly
    @State private var dayPage: Int?
    /// Идёт программный переход к дню: промежуточные страницы не выбираются.
    @State private var jumping = false
    @State private var sheetLesson: Lesson?
    @State private var showAccount = false
    @State private var banner: Banner?
    /// Перерисовка раз в минуту: «идёт сейчас» и «ещё N мин».
    @State private var minute = Date()
    /// Экран шире 1100 pt (iPad в альбомной ориентации): слева боковая
    /// панель с календарём загруженных недель.
    @State private var wide = false
    @State private var relogin = false

    private var showSidebar: Bool { sizeClass == .regular && wide }

    private var firstDay: Date { state.firstDay }
    private func dayAt(_ i: Int) -> Date { firstDay.adding(days: i) }
    private func index(of day: Date) -> Int { min(max(day.days(since: firstDay), 0), state.dayCount - 1) }

    @ViewBuilder
    private var root: some View {
        if showSidebar {
            NavigationSplitView(columnVisibility: .constant(.all)) {
                RangeCalendar(selected: selected, firstDay: firstDay, weeks: state.dayCount / 7,
                              hasLessons: { day in state.lessons(on: day).contains { !$0.cancelled } },
                              onSelect: { goTo($0) })
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(320)
            } detail: {
                mainStack
            }
        } else {
            mainStack
        }
    }

    private var mainStack: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    WeekColumns(week: selected.monday, minute: minute, open: { sheetLesson = $0 })
                } else {
                    dayPager
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaBar(edge: .top) { header }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                if Island.available && !reduceMotion {
                    IslandBanner(banner: banner) { self.banner = nil }
                } else if let banner {
                    BannerView(banner: banner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.banner = nil } }
                }
            }
        }
    }

    var body: some View {
        root
        .onGeometryChange(for: Bool.self) { $0.size.width >= 1100 } action: { wide = $0 }
        .sheet(item: $sheetLesson) { LessonSheet(lesson: $0) }
        .sheet(isPresented: $showAccount) { AccountView() }
        .sheet(isPresented: $relogin) { NavigationStack { LoginView(inSheet: true) } }
        .onAppear {
            dayPage = index(of: selected)
            openPendingLesson()
        }
        .task {
            await state.reloadDemoForScreenshots()
            await state.refresh(.open)
            await state.showLiveActivity()
            await state.checkNotifications(request: true)
            await WidgetTip.update()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 - Double(Calendar.current.component(.second, from: .now))))
                minute = Date()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await state.resumed() } }
        }
        .onChange(of: dayPage) { _, page in
            if !jumping, let page { selected = dayAt(page) }
        }
        .onChange(of: state.pendingLesson) { openPendingLesson() }
        .onChange(of: state.pendingToday) { _, today in
            guard today else { return }
            state.pendingToday = false
            showAccount = false
            sheetLesson = nil
            goTo(Clock.now)
        }
        .onChange(of: state.pendingChanges) { _, changes in
            guard !changes.isEmpty else { return }
            state.pendingChanges = []
            show(Banner(title: changes.count == 1 ? "Изменение в расписании" : "Изменения в расписании",
                        message: changes.joined(separator: "\n"), symbol: "calendar.badge.exclamationmark"),
                 for: 8)
        }
        .onChange(of: state.error) { _, error in
            guard let error, !state.loading else { return }
            show(Banner(title: "Не удалось обновить", message: error, symbol: "exclamationmark.circle.fill"), for: 5)
        }
    }

    private func show(_ banner: Banner, for seconds: Double) {
        withAnimation(.snappy) { self.banner = banner }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            withAnimation(.snappy) { if self.banner == banner { self.banner = nil } }
        }
    }

    /// Как в Календаре: к дальнему дню — один сдвиг страницы, без
    /// пролистывания всех промежуточных дней.
    private func goTo(_ day: Date) {
        let target = index(of: day)
        selected = dayAt(target)
        guard sizeClass != .regular, let current = dayPage, target != current else { return }
        jumping = true
        if abs(target - current) > 1 {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { dayPage = target > current ? target - 1 : target + 1 }
        }
        Task { @MainActor in
            withAnimation(.smooth(duration: 0.3)) { dayPage = target } completion: { jumping = false }
        }
    }

    /// Нажали на напоминание, Live Activity или виджет: день пары и её карточка.
    private func openPendingLesson() {
        guard let start = state.pendingLesson else { return }
        state.pendingLesson = nil
        guard let lesson = state.lessons.first(where: { abs($0.start.timeIntervalSince(start)) < 60 }) else { return }
        showAccount = false
        goTo(lesson.start)
        sheetLesson = lesson
    }

    /// Пролистали месяц: сегодня, если это текущий месяц, иначе 1-е число.
    private func goToMonth(_ month: Date) {
        let now = Clock.now
        goTo(month.year == now.year && month.month == now.month ? now : max(month, firstDay))
    }

    private var months: [Date] {
        let last = dayAt(state.dayCount - 1)
        var result: [Date] = []
        var m = calendar.date(from: calendar.dateComponents([.year, .month], from: firstDay))!
        while m <= last {
            result.append(m)
            m = calendar.date(byAdding: .month, value: 1, to: m)!
        }
        return result
    }

    // MARK: Шапка

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                MonthPager(months: months, selected: selected, onSwipe: goToMonth)
                if !selected.sameDay(Clock.now) {
                    Button("Сегодня") { goTo(Clock.now) }
                        .buttonStyle(.glass)
                        .transition(.opacity)
                }
                AccountButton { showAccount = true }
            }
            // Как у крупного заголовка системной навигации.
            .padding(.horizontal, 20)
            .animation(.snappy, value: selected.sameDay(Clock.now))
            // Крупный заголовок растёт со шрифтом меньше текста, как в системных
            // приложениях.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            // С боковой панелью недели выбирают в её календаре.
            if !showSidebar {
                WeekPager(selected: selected, firstDay: firstDay, weeks: state.dayCount / 7,
                          hasLessons: { day in state.lessons(on: day).contains { !$0.cancelled } },
                          onSelect: { goTo($0) })
                    // Семь дней в ряд: крупнее числа не помещаются.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
        .padding(.bottom, 6)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if state.sessionExpired && !state.sessionCardHidden && !state.demo {
                SessionExpiredCard(login: { relogin = true },
                                   later: { withAnimation(.snappy) { state.sessionCardHidden = true } })
                    .frame(maxWidth: 700)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Лента дней

    private var dayPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<state.dayCount, id: \.self) { i in
                    DayPage(day: dayAt(i), minute: minute, open: { sheetLesson = $0 }, openExams: { state.tab = .session })
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .clipHorizontally()
        .scrollPosition(id: $dayPage)
        .scrollIndicators(.hidden)
    }
}

/// Пары одного дня: карточка «Сейчас» (сегодня), лента с перерывами.
private struct DayPage: View {
    @Environment(AppState.self) private var state
    let day: Date
    let minute: Date
    let open: (Lesson) -> Void
    let openExams: () -> Void

    /// Подсказки по одной, по порядку.
    @State private var tips = TipGroup(.ordered) {
        RefreshTip()
        AccountTip()
        WidgetTip()
    }

    var body: some View {
        let lessons = state.lessons(on: day)
        let isToday = day.sameDay(Clock.now)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !lessons.isEmpty || isToday {
                    TipView(tips.currentTip)
                        .padding(.bottom, 12)
                }
                // Сессия скоро — карточка над сегодняшним днём.
                if isToday, let session = state.session,
                   session.showsCard(now: Clock.now) {
                    ExamCard(session: session, open: openExams)
                        .padding(.bottom, 12)
                }
                if lessons.isEmpty {
                    ContentUnavailableView {
                        Label(isToday ? "Сегодня пар нет" : "Пар нет", systemImage: "moon.zzz")
                    } description: {
                        if let next = state.next(after: isToday ? Clock.now : day.adding(days: 1)) {
                            Text("Следующая \(whenLabel(next.start))")
                        }
                    }
                    .padding(.top, 40)
                } else if isToday {
                    TodayTimeline(lessons: lessons, next: state.next(after: lessons.last!.end),
                                  now: Clock.now, open: open)
                } else {
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { i, lesson in
                        if i > 0 { GapRow(from: lessons[i - 1].end, to: lesson.start) }
                        TimelineRow(lesson: lesson, now: Clock.now) { open(lesson) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .id(minute)
        }
        .refreshable {
            RefreshTip().invalidate(reason: .actionPerformed)
            await state.refresh(.manual)
        }
    }
}

/// Лента сегодняшнего дня: что идёт сейчас, видно прямо в ней. Красная
/// линия с текущим временем — до начала, в перерыве и после конца пар,
/// как в Календаре. Во время пары её заменяет заполняющаяся полоска,
/// а остаток стоит в подписи пары.
private struct TodayTimeline: View {
    let lessons: [Lesson]
    /// Ближайшая пара после сегодняшних — для «Пары закончились».
    let next: Lesson?
    let now: Date
    let open: (Lesson) -> Void

    /// «через 40 мин» с округлением вверх: в последнюю минуту — «1 мин».
    private func left(_ until: Date) -> String { durationText(until.timeIntervalSince(now) + 59) }

    var body: some View {
        let active = lessons.filter { !$0.cancelled }
        let first = active.first
        let last = active.last
        VStack(alignment: .leading, spacing: 0) {
            if let first, now < first.start {
                NowLine(now: now)
                NowCaption(text: "Первая пара через \(left(first.start))")
            }
            ForEach(Array(lessons.enumerated()), id: \.element.id) { i, lesson in
                if i > 0 {
                    let from = lessons[i - 1].end
                    if from <= now && now < lesson.start && !lessons[i - 1].cancelled && !lesson.cancelled {
                        NowLine(now: now)
                        let long = lesson.start.timeIntervalSince(from) >= 3600
                        NowCaption(text: "\(long ? "Окно" : "Перерыв") · ещё \(left(lesson.start))")
                    } else {
                        GapRow(from: from, to: lesson.start)
                    }
                }
                TimelineRow(lesson: lesson, now: now,
                            remaining: lesson.isOngoing(at: now) ? "ещё \(left(lesson.end))" : nil) { open(lesson) }
            }
            if let last, now >= last.end {
                NowLine(now: now).padding(.top, 6)
                NowCaption(text: "Пары закончились")
                if let next {
                    NowCaption(text: "Следующая \(whenLabel(next.start)) — \(next.subject)", secondary: true)
                }
            }
        }
    }
}

/// Красная линия «сейчас»: время в колонке времени, линия — до края.
private struct NowLine: View {
    let now: Date
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = 48

    var body: some View {
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
        .padding(.top, 8)
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }
}

/// Подпись под линией «сейчас», с отступом колонки текста.
private struct NowCaption: View {
    let text: String
    var secondary = false
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = 48
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(text)
            .font(.footnote.weight(secondary ? .regular : .semibold))
            .foregroundStyle(secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
            .padding(.leading, 30)
            .padding(.bottom, secondary ? 8 : 2)
    }
}

/// Пара в ленте карточкой: время, название, тип и аудитория, преподаватель.
/// Слева цветная полоска типа; у идущей пары она заполняется по ходу пары,
/// а справа от времени — остаток.
struct TimelineRow: View {
    let lesson: Lesson
    let now: Date
    /// «ещё 40 мин» у идущей пары.
    var remaining: String? = nil
    let action: () -> Void

    var body: some View {
        let ongoing = lesson.isOngoing(at: now)
        let dimmed = lesson.cancelled || now > lesson.end
        let progress = ongoing ? now.timeIntervalSince(lesson.start) / lesson.end.timeIntervalSince(lesson.start) : nil
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                KindStripe(kind: lesson.kind, progress: progress)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(hm(lesson.start))–\(hm(lesson.end))")
                            .font(.subheadline.weight(ongoing ? .semibold : .medium))
                            .monospacedDigit()
                            .foregroundStyle(ongoing ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        Spacer(minLength: 8)
                        if let remaining {
                            Text(remaining)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    Text(lesson.subject)
                        .font(.headline)
                        .strikethrough(lesson.cancelled)
                    lessonDetails(lesson, icon: true)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !lesson.lecturer.isEmpty {
                        Text(lesson.lecturer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .opacity(dimmed ? 0.5 : 1)
        // VoiceOver читает карточку целиком: «10:40–12:00, Иностранный язык,
        // семинар, 1 - 2317, Морозова Ксения Олеговна, идёт сейчас».
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([
            "\(hm(lesson.start))–\(hm(lesson.end))", lesson.subject, lesson.kind,
            lesson.isRemote ? "дистанционно" : lesson.shortLocation, lesson.lecturer,
            lesson.cancelled ? "отменена" : "", ongoing ? "идёт сейчас" : "", remaining ?? "",
        ].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

/// Цветная полоска типа. У идущей пары заполняется сверху вниз по ходу пары.
struct KindStripe: View {
    let kind: String
    var progress: Double? = nil
    /// Без даты (сессия) — серая.
    var muted = false

    var body: some View {
        let color = muted ? Color(.systemGray3) : kindColor(kind)
        Capsule()
            .fill(progress == nil ? color : color.opacity(0.25))
            .overlay(alignment: .top) {
                if let progress {
                    GeometryReader { g in
                        Capsule().fill(color).frame(height: max(3, g.size.height * min(max(progress, 0), 1)))
                    }
                }
            }
            .frame(width: progress == nil ? 3 : 4)
    }
}

/// «Перерыв 20 мин» или «Окно 1 ч 40 мин» между парами.
struct GapRow: View {
    let from: Date
    let to: Date
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = 48
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let gap = to.timeIntervalSince(from)
        if gap > 0 {
            Text("\(gap >= 3600 ? "Окно" : "Перерыв") \(durationText(gap))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 30)
                .padding(.vertical, 6)
        } else {
            Spacer().frame(height: 8)
        }
    }
}
