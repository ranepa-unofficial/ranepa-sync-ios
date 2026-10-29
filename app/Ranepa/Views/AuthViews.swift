import SwiftUI
import WebKit

/// Почему не удалось войти — для окна на стартовом экране.
struct LoginFailure: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: Error) {
        switch error {
        case LKError.serverBusy:
            title = "Личный кабинет недоступен"
            message = "Не удалось получить данные из ЛК. Попробуй войти позже."
        case LKLoginError.timeout:
            title = "Личный кабинет не отвечает"
            message = "Попробуй войти позже."
        case LKLoginError.bounced:
            title = "Не удалось войти"
            message = "Попробуй ещё раз."
        default:
            title = "Не удалось войти"
            message = error.localizedDescription
        }
    }
}

enum LKLoginError: Error { case timeout, bounced }

/// Стартовый экран → вход в ЛК.
struct AuthFlow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            OnboardingView()
        }
    }
}

/// Стартовый экран до входа: что это за приложение и куда уходит пароль.
struct OnboardingView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        // Всё помещается — по центру; нет (крупный шрифт) — прокрутка.
        ViewThatFits(in: .vertical) {
            intro.frame(maxHeight: .infinity)
            ScrollView { intro }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                if let error = state.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
                NavigationLink {
                    LoginView()
                } label: {
                    Text("Войти").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                VStack(spacing: 4) {
                    Text("Неофициальное приложение")
                    Link(destination: URL(string: "https://github.com/Qteb/ranepa-sync")!) {
                        Label {
                            Text("Открытый код")
                        } icon: {
                            Image("GitHub").resizable().scaledToFit().frame(width: 13, height: 13)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .tint(.secondary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: 560)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(.rect(cornerRadius: 22))
                // Долгое нажатие: демо без ЛК для App Review и скриншотов.
                .onLongPressGesture {
                    Task { await state.startDemo() }
                }
                .sensoryFeedback(.impact, trigger: state.demo)
                .accessibilityHidden(true)
            Text("Расписание студента")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
            VStack(alignment: .leading, spacing: 22) {
                feature("calendar", "Расписание", "Пары до конца семестра, без интернета")
                feature("books.vertical", "Предметы", "Преподаватели, аудитории и все пары по предмету")
                feature("graduationcap", "Сессия", "Экзамены и зачёты по плану обучения")
                feature("lock", "Вход на сайте ЛК", "Логин и пароль приложение не видит")
            }
            .padding(.top, 36)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Вход идёт на настоящей странице ЛК: пароль вводится на сайте,
/// приложение его не видит и не хранит.
struct LoginView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// Повторный вход листом поверх расписания.
    var inSheet = false
    @State private var lk = LKWebView()
    @State private var pageLoading = true
    @State private var sawLoginForm = false
    @State private var fetching = false
    @State private var requested = false
    @State private var failed = false
    /// Ошибка повторного входа: окно поверх листа, по «OK» лист закрывается.
    @State private var sheetFailure: LoginFailure?
    @State private var timeout: Task<Void, Never>?

    var body: some View {
        WebView(lk: lk)
            .ignoresSafeArea(edges: .bottom)
            .overlay {
                if fetching {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.large).padding(.bottom, 8)
                        Text("Загружаю расписание…").font(.headline)
                        Text("Обычно это занимает несколько секунд").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(fetching ? "Расписание" : "Вход в ЛК")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(fetching)
            .toolbar {
                if pageLoading && !fetching {
                    ToolbarItem(placement: .topBarTrailing) { ProgressView() }
                }
                if inSheet && !fetching {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) { dismiss() }
                    }
                }
            }
            .onAppear {
                lk.onLoading = { pageLoading = $0 }
                lk.onURL = onURL
                lk.onFailure = { fail($0) }
                lk.onTemplate = { template in Task { await onTemplate(template) } }
                lk.load()
            }
            .onDisappear { timeout?.cancel() }
            .alert(sheetFailure?.title ?? "", isPresented: Binding(
                get: { sheetFailure != nil },
                set: { if !$0 { sheetFailure = nil } }
            ), presenting: sheetFailure) { _ in
                Button("OK", role: .cancel) { dismiss() }
            } message: { failure in
                Text(failure.message)
            }
    }

    private func onURL(_ url: URL?) {
        if LKWebView.isLoginPage(url) {
            sawLoginForm = true
            if fetching && !requested { fail(LKLoginError.bounced) }
        } else if sawLoginForm {
            // Ушли с формы входа — значит, вход прошёл. Сайт дальше грузится под
            // экраном загрузки: нам нужен только его запрос расписания.
            showLoading()
        }
    }

    private func showLoading() {
        guard !fetching else { return }
        fetching = true
        timeout?.cancel()
        timeout = Task {
            try? await Task.sleep(for: .seconds(60))
            if !Task.isCancelled && !requested { fail(LKLoginError.timeout) }
        }
    }

    /// Возвращает на стартовый экран, а он покажет, что случилось.
    private func fail(_ error: Error) {
        timeout?.cancel()
        guard !failed else { return }
        failed = true
        fetching = false
        if inSheet {
            sheetFailure = LoginFailure(error)
        } else {
            state.loginFailure = LoginFailure(error)
            dismiss()
        }
    }

    private func onTemplate(_ template: ScheduleTemplate) async {
        guard !requested else { return }
        requested = true
        showLoading()
        do {
            let monday = Date().monday
            let result = try await lk.fetch(template, monday: monday, weeks: semesterWeeks,
                                            stopAfterEmpty: emptyWeeksToStop, withPhoto: true, withPlan: true,
                                            withProgress: true)
            timeout?.cancel()
            await state.completeLogin(result, monday: monday)
            if inSheet { dismiss() }
        } catch {
            fail(error)
        }
    }
}

private struct WebView: UIViewRepresentable {
    let lk: LKWebView

    func makeUIView(context: Context) -> WKWebView { lk.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
