# Как это устроено

- **Данные.** Сайт закрыт JS-проверкой браузера, поэтому все запросы идут
  изнутри WebView. Приложение перехватывает запрос расписания, который делает
  сама страница (`n-api/schedule` с `uid_org` и всеми группами студента), и по
  его образцу запрашивает нужные недели ([`app/Ranepa/Services/LKClient.swift`](../app/Ranepa/Services/LKClient.swift)).
- **План обучения.** Тем же способом приложение берёт `uid_student` из
  `manual/student-groups` и загружает план (`education/plan`), даты сессий
  (`education/plan/sessions`) и справочники семестров и форм контроля. Запросы
  идут с теми же заголовками, что и запрос расписания. Из плана строятся
  «Предметы» ([`app/Ranepa/Core/StudyPlan.swift`](../app/Ranepa/Core/StudyPlan.swift),
  [`app/Ranepa/Core/Subjects.swift`](../app/Ranepa/Core/Subjects.swift)) и «Сессия»:
  экзамены и зачёты из плана сопоставляются с парами расписания, откуда берутся
  дата и аудитория ([`app/Ranepa/Core/Exams.swift`](../app/Ranepa/Core/Exams.swift)).
- **Изменения.** Новое расписание сравнивается с сохранённым; изменения в
  ближайшие 7 дней приходят одним уведомлением ([`app/Ranepa/Core/Changes.swift`](../app/Ranepa/Core/Changes.swift)).
- **Календарь.** EventKit ведёт отдельный календарь «РАНХиГС» и пересоздаёт
  события при каждом обновлении.
- **Виджет.** Приложение передаёт пары на 14 дней через App Group, виджет
  ([`app/RanepaWidget`](../app/RanepaWidget)) сам отбрасывает прошедшие пары.
- **Live Activity.** Видна, только пока идёт пара или следующая начнётся
  в ближайшие 2 часа; запустившись, остаётся до конца последней пары дня
  (`LiveActivityPlan` в [`app/Ranepa/Services/Outputs.swift`](../app/Ranepa/Services/Outputs.swift),
  тесты — [`app/RanepaTests/LiveActivityPlanTests.swift`](../app/RanepaTests/LiveActivityPlanTests.swift)).
  Запустить активность iOS даёт только из открытого приложения, поэтому
  оттуда же она заранее ставится на запуск по расписанию (iOS 26) — во время
  напоминания о первой паре дня. Уведомление этого запуска и есть
  напоминание: обычное о той же паре не ставится. Без напоминаний —
  только при открытии приложения.
  Обновлять и завершать можно и из фона: каждое фоновое пробуждение
  обновляет активность по сохранённому расписанию, даже если ЛК не ответил,
  а к концу последней пары приложение просит iOS разбудить его, чтобы её убрать.
  Сервера для push-обновлений нет, поэтому в активности сразу лежат
  идущая и следующая пара: когда первая заканчивается, расширение
  ([`app/RanepaWidget/LessonLiveActivity.swift`](../app/RanepaWidget/LessonLiveActivity.swift)) само показывает перемену.
- **Apple Watch.** После каждого обновления iPhone отправляет те же пары на
  часы через WatchConnectivity (`WatchSync` в [`app/Ranepa/Services/Outputs.swift`](../app/Ranepa/Services/Outputs.swift)).
  Приложение для часов ([`app/RanepaWatch`](../app/RanepaWatch)) сохраняет их у себя, усложнения
  ([`app/RanepaWatchWidget`](../app/RanepaWatchWidget)) читают оттуда. Сами часы в ЛК не ходят. Общая
  модель пар — [`app/Shared/Lessons.swift`](../app/Shared/Lessons.swift).
- **Статистика.** TelemetryDeck ([`app/Ranepa/Services/Analytics.swift`](../app/Ranepa/Services/Analytics.swift)):
  SDK запускается только из открытого приложения (фоновые пробуждения не
  считаются), в демо и без App ID (`TELEMETRYDECK_APP_ID` в `project.yml`)
  выключен. Кроме сессий SDK — `Login.completed`, `Sync.failed` (`reason`,
  `trigger`), `Screen.opened` (`screen`), `Support.opened` и раз в день
  `Settings.daily`; названия и параметры те же, что в Android-версии.
- **Интерфейс.** SwiftUI на системных компонентах iOS 26 (Liquid Glass) по
  Apple Human Interface Guidelines.
