import SwiftUI

/// Полоска баллов БРС, 0–100.
struct PointsBar: View {
    let points: Int
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.accentColor.opacity(0.14))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(height, g.size.width * CGFloat(min(max(points, 0), 100)) / 100))
                    .opacity(points > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Карточка наверху «Предметов»: средний балл БРС и посещаемость.
struct GradesCard: View {
    let progress: Progress

    var body: some View {
        HStack(spacing: 14) {
            if let average = progress.averagePoints {
                column(title: "Средний балл БРС", value: "\(average)", unit: "из 100",
                       note: "по \(progress.subjects.count) \(plural(progress.subjects.count, "предмету", "предметам", "предметам"))")
            }
            if progress.averagePoints != nil, progress.currentMonth != nil { Divider() }
            if let month = progress.currentMonth {
                column(title: "Посещаемость", value: "\(percent(month))%", unit: nil,
                       note: "\(month.name.lowercased()): \(month.fact) из \(month.plan)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func column(title: String, value: String, unit: String?, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title.bold()).monospacedDigit()
                if let unit { Text(unit).font(.subheadline).foregroundStyle(.secondary) }
            }
            Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func percent(_ m: Progress.Month) -> Int {
    m.plan > 0 ? Int((Double(m.fact) / Double(m.plan) * 100).rounded()) : 0
}

/// Секция «Успеваемость» на экране предмета.
struct SubjectGradesSection: View {
    let name: String
    let progress: Progress

    var body: some View {
        if let points = progress.points(for: name) {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(points)").font(.largeTitle.bold()).monospacedDigit()
                            Text("из 100 баллов").foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let delta = History.weekDelta(name, now: Clock.now), delta != 0 {
                            Text("\(delta > 0 ? "+" : "")\(delta) за неделю")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(delta > 0 ? Color.green : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((delta > 0 ? Color.green : .secondary).opacity(0.12)))
                        }
                    }
                    PointsBar(points: points, height: 8)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(points) из 100 баллов")
            } header: {
                Text("Успеваемость")
            } footer: {
                Text("Баллы БРС из личного кабинета, обновлено \(updated(progress.fetchedAt))")
            }
        }
    }
}

/// «сегодня в 08:40», «вчера в 21:10», «14 октября».
private func updated(_ t: Date) -> String {
    switch Clock.now.days(since: t) {
    case 0: "сегодня в \(hm(t))"
    case 1: "вчера в \(hm(t))"
    default: "\(t.day) \(monthsGenitive[t.month - 1])"
    }
}

/// Успеваемость: посещаемость по месяцам, средний балл, уведомления.
struct GradesView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let progress = state.progress
        List {
            if let progress, !progress.months.isEmpty {
                let current = progress.months.lastIndex { $0.fact > 0 } ?? -1
                Section {
                    ForEach(Array(progress.months.enumerated()), id: \.offset) { i, m in
                        monthRow(m, ahead: i > current)
                    }
                } header: {
                    Text("Посещаемость")
                } footer: {
                    Text("Посещённые занятия из запланированных, как в личном кабинете")
                }
            }
            Section("Средний балл") {
                if let progress, progress.averageBrs != nil || progress.rating != nil {
                    if let brs = progress.averageBrs { LabeledContent("По 100-балльной шкале", value: brs) }
                    if let rating = progress.rating { LabeledContent("По 5-балльной шкале", value: rating) }
                } else {
                    Text("Появится после первой сессии").foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Новые баллы", isOn: Binding(get: { state.gradeNotifications },
                                                    set: { v in Task { await state.setGradeNotifications(v) } }))
            } header: {
                Text("Уведомления")
            } footer: {
                Text("Приложение проверяет баллы раз в день и при обновлении расписания жестом «потянуть вниз».")
            }
        }
        .navigationTitle("Успеваемость")
        .onAppear { Analytics.screen("grades") }
    }

    private func monthRow(_ m: Progress.Month, ahead: Bool) -> some View {
        HStack(spacing: 12) {
            Text(m.name)
                .foregroundStyle(ahead ? .secondary : .primary)
                .frame(width: 92, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.green.opacity(0.14))
                    Capsule().fill(Color.green)
                        .frame(width: g.size.width * CGFloat(ahead ? 0 : percent(m)) / 100)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
            Text(ahead ? "впереди" : "\(m.fact) из \(m.plan)")
                .monospacedDigit()
                .foregroundStyle(ahead ? .secondary : .primary)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
