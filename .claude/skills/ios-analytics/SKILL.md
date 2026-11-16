---
name: ios-analytics
description: Анонимная статистика TelemetryDeck в iOS-приложении — как устроена обёртка Analytics, схема событий (общая с Android), как добавить событие, что обновить в политике и «Конфиденциальности приложения», как проверить, что сигналы доходят. Использовать, когда просят добавить или поменять событие статистики, спрашивают про TelemetryDeck, DAU, удержание, или сигналы не видны в панели.
---

# Статистика (TelemetryDeck)

## Где код

- [`app/Ranepa/Services/Analytics.swift`](../../../app/Ranepa/Services/Analytics.swift) — единственная точка входа: `start`, `stop`, `signal`, `screen`, `syncFailed`, `daily`.
- App ID — `TELEMETRYDECK_APP_ID` в `app/project.yml` → Info.plist `TelemetryDeckAppID`. Пусто — статистика выключена. Не секрет.
- Тесты — `app/RanepaTests/AnalyticsTests.swift` (причины ошибок, раз в сутки).

## Правила, на которых держится подсчёт

- `start()` — только из `scenePhase == .active` в `RanepaApp`: `initialize` сразу шлёт `Session.started`, и запуск в `App.init` считал бы фоновые обновления и виджеты пользователями.
- Выключена в демо-режиме и режимах скриншотов/записи (`allowed()`); при входе в демо — `stop()`.
- `DEBUG` и `TEST_TOOLS` — `testMode = true`.
- Переключателя для пользователя нет, пока не попросят.

## Схема событий — одинаковая с Android

| Событие | Параметры | Где |
|---|---|---|
| `Login.completed` | — | конец входа, не повторный вход после истёкшей сессии |
| `Sync.failed` | `reason` network/session/server/other, `trigger` open/manual | обновление на глазах у пользователя |
| `Screen.opened` | `screen` | смена вкладки; для экранов в стеке — один раз за показ |
| `Support.opened` | — | кнопка поддержки в «О приложении» |
| `Settings.daily` | включённые функции строками | раз в календарный день |

Новое событие или параметр — сразу и в Android (скилл `ios-to-android`). Никогда не отправлять ФИО, логин, группу, расписание, свободный текст.

## Если меняется, что отправляется

1. `PRIVACY.md` (обе локали): список событий и что **не** отправляется. Приложение показывает политику из репозитория — пользователи увидят её после мержа.
2. «Конфиденциальность приложения» на сайте: Usage Data → Product Interaction (+ Diagnostics → Other Diagnostic Data, если уходят ошибки), цель Analytics, не связано с личностью, без отслеживания → **Publish**.
3. Описание и заметки для проверки в App Store — они наследуются (скилл `ios-release`).

## Проверить, что сигналы доходят

- Панель → Explore → Recent Signals. Сборки Xcode — только с **Test Mode**, TestFlight и App Store — без него.
- На бесплатном тарифе отчёты запаздывают («Queued for Data Processing»), Recent Signals — обычно за минуты.
- Ничего нет: не тот фильтр Test Mode, включён демо-режим, приложение не становилось активным; трафик на `nom.telemetrydeck.com` видно в Proxyman.
