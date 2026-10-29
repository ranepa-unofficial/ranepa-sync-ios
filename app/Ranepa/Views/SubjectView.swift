import SwiftUI

/// Предмет: следующая пара, экзамен, преподаватели, где обычно проходит,
/// все пары по месяцам.
struct SubjectView: View {
    let name: String
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var lesson: Lesson?
    @State private var expanded: Set<Int> = []
    @State private var copied: String?
    /// Заголовок в ленте ушёл под шапку — показываем его в шапке.
    @State private var titleHidden = false

    var body: some View {
        let subject = Subject(name: name, lessons: state.lessons.filter { $0.subject == name }, now: Clock.now)
        List {
            // Названия длинные («Элективные дисциплины по физической культуре
            // и спорту»): крупный заголовок навигации их обрезает, свой —
            // переносит.
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.title.bold())
                    if let line = planLine { Text(line).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
                    Text(subject.lessons.isEmpty ? "Пар в расписании нет" : subject.upcomingSummary).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            if let progress = state.progress { SubjectGradesSection(name: name, progress: progress) }
            if let next = subject.next {
                Section("Следующая") {
                    Button { lesson = next } label: { LessonListRow(lesson: next, showSubject: false) }
                        .foregroundStyle(Color(.label))
                }
            }
            if let exam = subject.exam {
                Section(exam.kind.capitalizedFirst) {
                    Button { lesson = exam } label: {
                        LessonListRow(lesson: exam, showSubject: false, note: subject.consultation.map { c in
                            "Консультация — \(shortWhen(c.start))\(c.isRemote ? ", дистанционно" : ", \(c.shortLocation)")"
                        })
                    }
                        .foregroundStyle(Color(.label))
                }
            }
            if !subject.lecturers.isEmpty {
                Section(subject.lecturers.count == 1 ? "Преподаватель" : "Преподаватели") {
                    ForEach(subject.lecturers, id: \.name) { lecturerRow($0) }
                }
            }
            if !subject.kinds.isEmpty {
                Section("Занятия") {
                    ForEach(subject.kinds, id: \.kind) { kindRow($0) }
                    if let lms = subject.lmsLink {
                        Link(destination: lms) {
                            HStack {
                                Label("Курс в СДО", systemImage: "book")
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                    }
                }
            }
            months(subject)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle(titleHidden ? name : "")
        .navigationBarTitleDisplayMode(.inline)
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 60 } action: { _, hidden in
            withAnimation(.easeInOut(duration: 0.15)) { titleHidden = hidden }
        }
        .sheet(item: $lesson) { LessonSheet(lesson: $0, from: .subject(name)) }
        .alert("Адрес скопирован", isPresented: Binding(get: { copied != nil }, set: { if !$0 { copied = nil } })) {
        } message: { Text(copied ?? "") }
    }

    /// «Зачёт · 72 ч · 2 з. е. · 1-й семестр» — из плана обучения.
    private var planLine: String? {
        guard let plan = state.plan else { return nil }
        let current = plan.currentSemester(now: Clock.now)
        guard let item = plan.item(named: name, semester: current) ?? plan.item(named: name, semester: nil) else { return nil }
        var parts = [item.form].compactMap { $0 }
        if item.hours > 0 { parts.append("\(item.hours) ч") }
        if item.ze > 0 { parts.append("\(item.ze) з. е.") }
        if item.semesterNumber != current { parts.append(item.semester) }
        return parts.joined(separator: " · ")
    }

    private func lecturerRow(_ l: Subject.Lecturer) -> some View {
        NavigationLink(value: Route.lecturer(l.name)) { lecturerLabel(l) }
    }

    private func lecturerLabel(_ l: Subject.Lecturer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.name)
                Text(([l.kinds.enumerated().map { $0 == 0 ? $1 : $1.lowercased() }.joined(separator: " и ")].filter { !$0.isEmpty } + (l.upcoming > 0 ? ["\(l.upcoming) впереди"] : []))
                        .joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !l.email.isEmpty {
                Button {
                    openMail(l.email, subject: name, openURL: openURL) { copied = l.email }
                } label: {
                    Image(systemName: "envelope.fill")
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.accentColor.opacity(0.12)))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Написать \(l.name)")
            }
        }
    }

    private func kindRow(_ k: Subject.KindSummary) -> some View {
        HStack(spacing: 12) {
            KindStripe(kind: k.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(kindPlural(k.kind))
                Text([k.upcoming > 0 ? "\(k.upcoming) впереди" : "все прошли", k.usualRoom.map { "обычно \($0)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// Все пары по месяцам: ближайший месяц развёрнут, остальные — по нажатию.
    @ViewBuilder
    private func months(_ subject: Subject) -> some View {
        let lessons = subject.lessons.filter { $0.end > Clock.now.dateOnly }
        let groups = Dictionary(grouping: lessons) { $0.start.year * 100 + $0.start.month }
        ForEach(Array(groups.keys.sorted().enumerated()), id: \.element) { index, key in
            let items = groups[key]!
            let open = index == 0 || expanded.contains(key)
            Section("\(monthsNominative[key % 100 - 1]) · \(items.count) \(plural(items.count, "пара", "пары", "пар"))") {
                if open {
                    ForEach(items) { l in
                        Button { lesson = l } label: { LessonListRow(lesson: l, showSubject: false) }
                            .foregroundStyle(Color(.label))
                    }
                } else {
                    Button("Показать") { withAnimation { _ = expanded.insert(key) } }
                }
            }
        }
    }
}
