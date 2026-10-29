import SwiftUI

private let reminderOptions = [0, 5, 10, 15, 30, 60]

/// Аккаунт и настройки одним листом, как аккаунт в App Store. На iPad —
/// окном по центру.
struct AccountView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmLogout = false
    @State private var explainNotifications = false
    /// Возврат из «О приложении» — не новое открытие аккаунта.
    @State private var counted = false

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        AvatarView(size: 84).padding(.bottom, 8)
                        Text(state.fullName ?? "Студент")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        ForEach([state.group, state.program].compactMap { $0 }.filter { !$0.isEmpty }, id: \.self) {
                            Text($0)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .copyable($0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                UpdateRow(updates: Updates.shared)

                Section {
                    if state.notificationsEnabled == false {
                        Button { explainNotifications = true } label: {
                            LabeledContent {
                                Text("Выключены")
                            } label: {
                                Label { Text("Напоминание").foregroundStyle(Color(.label)) } icon: { SettingsIcon("bell.fill", .red) }
                            }
                        }
                    } else {
                        Picker(selection: Binding(get: { state.reminderMinutes },
                                                  set: { m in Task { await state.setReminderMinutes(m) } })) {
                            ForEach(reminderOptions, id: \.self) { m in
                                Text(m == 0 ? "Выкл." : "За \(m) мин").tag(m)
                            }
                        } label: {
                            Label { Text("Напоминание") } icon: { SettingsIcon("bell.fill", .red) }
                        }
                    }
                    Toggle(isOn: Binding(get: { state.calendarExport },
                                         set: { v in Task { await state.setCalendarExport(v) } })) {
                        Label { Text("Добавлять в Календарь") } icon: { SettingsIcon("calendar", .orange) }
                    }
                    if isPhone {
                        Toggle(isOn: Binding(get: { state.liveActivity },
                                             set: { v in Task { await state.setLiveActivity(v) } })) {
                            Label { Text("Live Activity") } icon: { SettingsIcon("timer", .green) }
                        }
                    }
                    // Какими картами открывать адрес корпуса: если их больше одной.
                    if MapApp.installedApps.count > 1 {
                        Picker(selection: Binding(get: { MapApp.preferred?.rawValue ?? "" },
                                                  set: {
                                                      MapApp.preferred = MapApp(rawValue: $0)
                                                      // Виджеты и «Корпус» в Пункте управления открывают те же Карты.
                                                      Outputs.update(state.lessons)
                                                  })) {
                            Text("Спрашивать").tag("")
                            ForEach(MapApp.installedApps) { Text($0.title).tag($0.rawValue) }
                        } label: {
                            Label { Text("Карты") } icon: { SettingsIcon("map.fill", .teal) }
                        }
                    }
                    Picker(selection: Binding(get: { state.themeMode }, set: { state.setThemeMode($0) })) {
                        Text("Авто").tag(0)
                        Text("Светлое").tag(1)
                        Text("Тёмное").tag(2)
                    } label: {
                        Label { Text("Оформление") } icon: { SettingsIcon("moon.fill", .indigo) }
                    }
                } footer: {
                    Text(footer)
                }

                #if DEBUG || TEST_TOOLS
                if Clock.debugTools { DebugSection() }
                #endif

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label { Text("О приложении") } icon: { SettingsIcon(logo: "Logo") }
                    }
                }

                Section {
                    Button(logoutTitle, role: .destructive) { confirmLogout = true }
                        .frame(maxWidth: .infinity)
                        .confirmationDialog(logoutTitle, isPresented: $confirmLogout, titleVisibility: .hidden) {
                            Button(logoutTitle, role: .destructive) {
                                dismiss()
                                Task { await state.logout() }
                            }
                        } message: {
                            Text(state.demo
                                 ? "Демо-расписание, напоминания и календарь «\(CalendarExport.name)» будут удалены."
                                 : "Расписание, напоминания и календарь «\(CalendarExport.name)» будут удалены с этого iPhone.")
                        }
                }
            }
            // Строки с переключателями: на самых крупных размерах подписи
            // не помещаются даже в несколько строк.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            // Профиль сразу под крестиком, как в аккаунте App Store.
            .contentMargins(.top, 0, for: .scrollContent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .onAppear {
                Updates.shared.markSeen()
                guard !counted else { return }
                counted = true
                Analytics.screen("account")
            }
            .alert("Уведомления выключены", isPresented: $explainNotifications) {
                Button("Отмена", role: .cancel) {}
                Button("Открыть Настройки") {
                    openURL(URL(string: UIApplication.openNotificationSettingsURLString)!)
                }
            } message: {
                Text("Чтобы получать напоминания о парах и изменениях в расписании, разреши уведомления в Настройках.")
            }
        }
    }

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    private var logoutTitle: String { state.demo && !Clock.screenshotMode ? "Выйти из демо" : "Выйти из ЛК" }

    private var footer: String {
        // Что делает переключатель Live Activity — всегда, раз название
        // английское. На iPad Live Activity нет.
        let live = isPhone ? "Live Activity — текущая пара на экране блокировки и в Dynamic Island. " : ""
        if state.demo && !Clock.screenshotMode {
            return live + "Демо-режим: профиль и расписание выдуманы, приложение не обращается к ЛК. "
                + "«Выйти из демо» удалит и календарь «\(CalendarExport.name)»."
        }
        var parts: [String] = live.isEmpty ? [] : [live.trimmingCharacters(in: .whitespaces)]
        if state.notificationsEnabled == false {
            parts.append("Уведомления выключены — об изменениях в расписании ты не узнаешь.")
        }
        if state.calendarExport { parts.append("Пары добавляются в отдельный календарь «\(CalendarExport.name)».") }
        parts.append("В будни днём расписание обновляется в фоне примерно раз в час, ночью и в выходные — реже.")
        if !state.demo {
            parts.append(state.lastBackgroundRun.map {
                "Последнее фоновое обновление — \($0.sameDay(Clock.now) ? "сегодня" : shortDate($0)) в \(hm($0))."
            } ?? "В фоне ещё не обновлялось.")
        }
        return parts.joined(separator: " ")
    }
}

#if DEBUG || TEST_TOOLS
/// Отладка: в отладочной сборке и в тестовой для своего iPhone.
private struct DebugSection: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Section {
            debugRow("Ускоренный день", "Демо: 4 пары по 4 мин, первая через 3 мин") {
                dismiss()
                Task { await state.startFastDay() }
            }
            debugRow("Напоминание о паре", "Через 5 секунд — заблокируй телефон") {
                let now = Clock.now
                if let lesson = state.lessons.first(where: { !$0.cancelled && $0.start > now }) ?? state.lessons.last {
                    Task { await Notifications.showTest(lesson, minutes: min(max(state.reminderMinutes, 1), 60)) }
                }
            }
            debugRow("Уведомление об изменении", "Показать сразу, как после обновления") {
                Task { await Notifications.showChanges(["Математика, ср 14.10: перенесли с 12:20 на 14:00"]) }
            }
            debugRow("Обновить Live Activity", "Запустить или обновить по сегодняшним парам") {
                Task { await state.showLiveActivity() }
            }
            debugRow("Фоновое обновление", "Как по расписанию системы, без проверок") {
                Task {
                    await Background.run(debug: true)
                    state.loadCache()
                }
            }
            debugRow("Сымитировать изменение", "Сдвигает ближайшую пару на час раньше") {
                Background.debugShiftNextLesson()
                state.loadCache()
            }
        } header: {
            Text("Отладка")
        } footer: {
            Text("Последний результат: \(state.lastBackgroundResult ?? "—")")
        }
    }

    private func debugRow(_ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Color(.label))
                Text(subtitle).font(.footnote).foregroundStyle(Color(.secondaryLabel))
            }
        }
    }
}
#endif
