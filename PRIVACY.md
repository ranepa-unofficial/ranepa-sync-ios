# Политика конфиденциальности «Расписание студента»

Дата вступления в силу: 26 октября 2026 г.

«Расписание студента» — неофициальное приложение для студентов РАНХиГС. Оно не связано с РАНХиГС и не поддерживается академией.

## Что приложение не делает

- Не видит и не сохраняет логин и пароль от личного кабинета.
- Не передаёт разработчику и третьим лицам расписание, ФИО, группу и другие данные из личного кабинета. У приложения нет своих серверов.
- Не показывает рекламу, не отслеживает вас в других приложениях и на сайтах.

## Как работает вход

Вход выполняется на странице личного кабинета РАНХиГС, открытой внутри приложения. Логин и пароль вводятся на сайте академии и отправляются только ему. После входа сайт сохраняет на устройстве свои cookie и данные сессии. Приложение использует их, чтобы загружать расписание и данные профиля из личного кабинета.

Обработку данных на сайте личного кабинета регулируют правила РАНХиГС.

## Какие данные загружаются из личного кабинета

- Расписание: пары, аудитории, преподаватели и их рабочая почта, группы, ссылки на курсы в СДО.
- Профиль: фамилия, имя и отчество, группа, программа обучения и фотография из личного кабинета. Они показываются на экране аккаунта. Фотография уменьшается и сохраняется на устройстве; заново она загружается не чаще раза в неделю.

## Какие данные хранятся на устройстве

- Расписание и профиль из списка выше — чтобы приложение работало без интернета.
- Время последнего обновления и результат последнего фонового обновления.
- Настройки приложения.
- Ближайшие пары для виджета на главном экране. Они хранятся в общей области приложения и его виджета на этом же устройстве.

Эти данные хранятся только на устройстве и никуда не передаются.

## Фоновое обновление

Приложение обновляет расписание в фоне: в будни днём — примерно раз в час, ночью и в субботу — реже, в воскресенье — раз в 12 часов. Время запуска выбирает система телефона. Запросы идут только на сайт личного кабинета РАНХиГС — так же, как при ручном обновлении. Каждое обновление продлевает сессию личного кабинета, поэтому входить заново не нужно.

## Анонимная статистика

Чтобы понимать, сколько человек пользуется приложением и какие разделы нужны, приложение отправляет анонимную статистику в сервис TelemetryDeck (TelemetryDeck GmbH, Германия; данные хранятся в ЕС).

- **Идентификатор.** При первом запуске приложение создаёт случайный идентификатор установки. На сервис уходит только его хэш, вычисленный на устройстве; TelemetryDeck хэширует его ещё раз. Связать его с вами, вашим логином или устройством нельзя.
- **Что отправляется.** Открытие приложения (начало сессии), успешный вход в личный кабинет, неудачное обновление расписания (только причина: нет сети, истекла сессия, ЛК недоступен), открытие разделов «Предметы», «Сессия», «Поиск», «Аккаунт», «О приложении», нажатие «Поддержка в Telegram» и раз в день — какие функции включены (напоминание, уведомления, календарь, Live Activity, виджет, Apple Watch, оформление).
- **Вместе с событием** — версия приложения и системы, модель устройства и размер экрана, язык, регион и часовой пояс, тема и размер шрифта.
- **Не отправляется** логин, пароль, ФИО, группа, расписание, IP-адрес (TelemetryDeck его не сохраняет), рекламный идентификатор.
- Фоновое обновление, виджеты и часы статистику не отправляют. В демо-режиме её нет.

Политика TelemetryDeck: https://telemetrydeck.com/privacy/

## Разрешения

- **Уведомления** — для напоминаний перед парами, сообщений об изменениях в расписании (перенос, отмена, новая пара, другая аудитория) и напоминания открыть приложение, если оно давно не обновлялось и сессия скоро истечёт. Все уведомления создаются на самом устройстве.
- **Календарь** — только если включить выгрузку пар. Приложение создаёт отдельный календарь «РАНХиГС» и работает только с ним. Календарь создаётся средствами iOS: если на устройстве включена синхронизация календарей iCloud, iOS может создать его в iCloud, и тогда Apple синхронизирует его между вашими устройствами по своим правилам.

Оба разрешения необязательные. Их можно отозвать в настройках телефона.

## Удаление данных

Кнопка «Выйти из ЛК» на экране аккаунта (нажмите на свою фотографию на главном экране) удаляет:

- сохранённое расписание и профиль, включая фотографию;
- cookie и данные сессии личного кабинета;
- запланированные напоминания и фоновое обновление;
- данные виджета;
- календарь «РАНХиГС».

При удалении приложения с телефона удаляются все его данные, включая идентификатор статистики. Уже отправленная статистика анонимна и хранится в TelemetryDeck в обобщённом виде.

## TestFlight

Во время бета-тестирования Apple может собирать отчёты о сбоях и отзывы, которые вы отправляете через TestFlight. Это происходит по правилам Apple: https://www.apple.com/legal/privacy/

## Изменения и контакты

Если политика изменится, новая версия появится на этой странице.

Вопросы можно отправить на почту: qtebest.dev@gmail.com

---

# Privacy Policy — "Расписание студента" (Student Timetable)

Effective date: October 26, 2026

This is an unofficial app for RANEPA students. It is not affiliated with or endorsed by RANEPA.

## What the app does not do

- It never sees or stores your student portal username or password.
- It does not send your timetable, name, group or any other portal data to the developer or third parties. The app has no servers of its own.
- It shows no ads and does not track you across other apps or websites.

## How sign-in works

You sign in on the RANEPA student portal page, opened inside the app. Your username and password are entered on the university's website and sent only to it. After sign-in, the website stores its own cookies and session data on your device. The app uses them to download your timetable and profile details from the portal.

RANEPA's own policies govern how the portal handles your data.

## Data downloaded from the portal

- Timetable: classes, rooms, lecturers and their work email addresses, groups, and links to courses in the university's learning system.
- Profile: your full name, group, study programme and profile photo from the portal. They are shown on the account screen. The photo is downscaled and stored on your device, and is downloaded again at most once a week.

## Data stored on your device

- The timetable and profile listed above, so the app works offline.
- The time of the last update and the result of the last background update.
- App settings.
- Upcoming classes for the home screen widget. They are kept in a storage area shared by the app and its widget on the same device.

This data stays on your device and is never transmitted elsewhere.

## Background updates

The app updates your timetable in the background: about once an hour on weekday daytime, less often at night and on Saturdays, and every 12 hours on Sundays. Your phone's system decides exactly when to run them. Requests go only to the RANEPA student portal, the same as a manual refresh. Each update extends your portal session, so you don't need to sign in again.

## Anonymous usage statistics

To understand how many people use the app and which sections matter, the app sends anonymous usage statistics to TelemetryDeck (TelemetryDeck GmbH, Germany; data stored in the EU).

- **Identifier.** On first launch the app creates a random installation identifier. Only a hash of it, computed on the device, is sent; TelemetryDeck hashes it again. It cannot be linked to you, your username or your device.
- **What is sent.** App opens (session starts), a successful portal sign-in, a failed timetable update (only the reason: no network, session expired, portal unavailable), opening the Subjects, Session, Search, Account and About sections, tapping "Support in Telegram", and once a day which features are on (reminder, notifications, calendar, Live Activity, widget, Apple Watch, appearance).
- **Sent with each event:** app and OS version, device model and screen size, language, region and time zone, appearance and text size.
- **Never sent:** your username, password, name, group, timetable, IP address (TelemetryDeck does not store it) or advertising identifier.
- Background updates, widgets and the watch app send no statistics. Demo mode sends none.

TelemetryDeck's policy: https://telemetrydeck.com/privacy/

## Permissions

- **Notifications**: for reminders before classes, alerts about timetable changes (a class moved, cancelled, added or moved to another room), and a reminder to open the app if it hasn't updated for a long time and your session is about to expire. All notifications are created on the device itself.
- **Calendar**: only if you turn on calendar export. The app creates a separate "РАНХиГС" calendar and works only with that calendar. The calendar is created through iOS: if iCloud Calendar sync is on, iOS may create it in iCloud, and Apple will then sync it across your devices under its own policy.

Both permissions are optional. You can revoke them in your phone's settings.

## Deleting your data

"Выйти из ЛК" (Sign out) on the account screen (tap your photo on the main screen) deletes:

- the saved timetable and profile, including the photo;
- the portal's cookies and session data;
- scheduled reminders and background updates;
- the widget's data;
- the "РАНХиГС" calendar.

Deleting the app removes all of its data, including the statistics identifier. Statistics already sent are anonymous and kept by TelemetryDeck in aggregated form.

## TestFlight

During beta testing, Apple may collect crash reports and feedback that you send through TestFlight, under Apple's own policy: https://www.apple.com/legal/privacy/

## Changes and contact

If this policy changes, the updated version will be posted on this page.

Questions: qtebest.dev@gmail.com
