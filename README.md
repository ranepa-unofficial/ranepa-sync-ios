# Расписание студента

Неофициальное приложение для iPhone, iPad и Apple Watch с расписанием РАНХиГС.
Расписание берётся из личного кабинета студента (my.ranepa.ru) и открывается
сразу, без браузера и без входа в ЛК каждый раз.

> Приложение не связано с РАНХиГС и не поддерживается академией.

<p align="center">
  <a href="https://apps.apple.com/ru/app/id6822034998"><img src="docs/badges/appstore-badge-ru.svg" height="48" alt="Загрузите в App Store"></a>
  &nbsp;
  <a href="https://testflight.apple.com/join/evTDn2DB"><img src="docs/badges/testflight-badge-ru.svg" height="48" alt="Бета-версия в TestFlight"></a>
</p>

<p align="center">
  <img src="docs/images/schedule.jpg" width="24%" alt="Расписание">
  <img src="docs/images/lesson.jpg" width="24%" alt="Карточка пары">
  <img src="docs/images/session.jpg" width="24%" alt="Сессия">
  <img src="docs/images/subject.jpg" width="24%" alt="Экран предмета">
</p>

## Установка

Приложение есть в [App Store](https://apps.apple.com/ru/app/id6822034998).
Новые версии до выхода в App Store можно попробовать в [TestFlight](https://testflight.apple.com/join/evTDn2DB).
Нужен iPhone или iPad с iOS 26. Версия для Android —
[ranepa-sync-android](https://github.com/ranepa-unofficial/ranepa-sync-android).

## Что умеет

- Пары дня с текущей и следующей парой, на iPad — вся неделя.
- Расписание до конца семестра, работает без интернета.
- Уведомления о переносах, отменах и смене аудитории, напоминания о паре.
- «Предметы» и «Сессия» из плана обучения: экзамены, зачёты, преподаватели.
- Виджеты, Live Activity, «Корпус» в Пункте управления, календарь «РАНХиГС».
- Apple Watch: пары на неделю и усложнения.

## Приватность

Своих серверов и рекламы нет. Логин и пароль вводятся на настоящей
странице ЛК, приложение их не видит. Расписание и профиль хранятся только на
телефоне. Анонимная статистика (сколько пользователей, какие разделы открывают)
уходит в [TelemetryDeck](https://telemetrydeck.com).
Подробнее — в [политике конфиденциальности](PRIVACY.md) и в разделе
[«Вход и токены»](docs/auth.md).

## Документация

- [Вход и токены](docs/auth.md)
- [Как обновляется расписание](docs/sync.md)
- [Как это устроено](docs/architecture.md)
- [Сборка и разработка](docs/development.md)

## Сборка

Нужны Xcode 26 и [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd app && xcodegen generate && open Ranepa.xcodeproj
```

Тесты, демо-режим и сборка под своим аккаунтом — в [docs/development.md](docs/development.md).

## Состояние

Версия 1.x была на Flutter, с 2.0 приложение нативное (SwiftUI, iOS 26).
Стабильные версии выходят в App Store, бета-версии — в TestFlight.

## Лицензия

[MIT](LICENSE)
