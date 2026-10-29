import SwiftUI

/// Куда можно перейти из карточки пары, предмета или поиска.
enum Route: Hashable {
    case subject(String)
    case lecturer(String)
    case plan
    case grades
}

extension View {
    /// Экраны предмета и преподавателя для любого NavigationStack.
    /// [shown] — экран открылся (лист раскрывается на весь экран).
    func routes(shown: @escaping () -> Void = {}) -> some View {
        navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .subject(let name): SubjectView(name: name)
                case .lecturer(let name): LecturerView(name: name)
                case .plan: PlanView()
                case .grades: GradesView()
                }
            }
            .onAppear(perform: shown)
        }
    }
}

/// Преподаватель: почта, его предметы и ближайшие пары.
struct LecturerView: View {
    let name: String
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var lesson: Lesson?
    @State private var copied = false

    var body: some View {
        let now = Clock.now
        let own = state.lessons.filter { $0.lecturer == name }
        let email = own.first { !$0.email.isEmpty }?.email ?? ""
        let subjects = Subject.all(own, now: now)
        let upcoming = own.filter { !$0.cancelled && $0.end > now }
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.title.bold())
                    Text(upcoming.isEmpty ? "Пар больше нет"
                         : "Впереди \(upcoming.count) \(plural(upcoming.count, "пара", "пары", "пар"))")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            if !email.isEmpty {
                Section {
                    Button {
                        openMail(email, openURL: openURL) { copied = true }
                    } label: {
                        Label(email, systemImage: "envelope")
                    }
                    .copyable(email)
                }
            }
            Section(subjects.count == 1 ? "Предмет" : "Предметы") {
                ForEach(subjects) { s in
                    NavigationLink(value: Route.subject(s.name)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                            Text(s.kinds.map { kindPlural($0.kind) }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !upcoming.isEmpty {
                Section("Ближайшие пары") {
                    ForEach(upcoming.prefix(10)) { l in
                        Button { lesson = l } label: { LessonListRow(lesson: l) }
                            .foregroundStyle(Color(.label))
                    }
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $lesson) { LessonSheet(lesson: $0, from: .lecturer(name)) }
        .alert("Адрес скопирован", isPresented: $copied) {} message: { Text(email) }
    }
}
