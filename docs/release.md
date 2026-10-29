# Выпуск новой версии

Порядок для каждой сборки, которая уходит пользователям через TestFlight или App Store.
Последний шаг — манифест обновлений `update.json`. Без него приложение не узнает
о новой версии, а при неверных номерах предложит обновиться на версию, которой ещё нет.

## 1. Номер сборки и версия

В [`app/project.yml`](../app/project.yml):

- `CURRENT_PROJECT_VERSION` — номер сборки, на 1 больше предыдущего. Каждая загрузка
  в App Store Connect требует нового номера.
- `MARKETING_VERSION` — версия, которую видят пользователи (`2.3.0`). Меняется,
  когда выходит новая версия, а не очередная сборка той же.

```bash
cd app
xcodegen generate
```

Изменение — отдельной веткой `build-<версия>-<сборка>` и PR «Сборка 2.3.0 (40)».

## 2. Архив и загрузка

```bash
cd app
xcodebuild -project Ranepa.xcodeproj -scheme Ranepa -configuration Release \
  -destination 'generic/platform=iOS' -archivePath ../build/ios/Ranepa.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath ../build/ios/Ranepa.xcarchive -exportPath ../build/ios/upload \
  -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
```

[`app/ExportOptions.plist`](../app/ExportOptions.plist) сразу загружает сборку в App Store Connect.
Архив складывается в `build/` в корне репозитория, она в `.gitignore`.

## 3. TestFlight

1. Дождаться обработки: 10–30 минут, придёт письмо.
2. Сборка → Test Details → **What to Test**: что изменилось и что проверить.
3. Добавить сборку во внешнюю группу с публичной ссылкой. Если Apple попросит
   бета-ревью, дождаться его.

## 4. App Store

Новая версия → выбрать сборку → отправить на проверку. После одобрения выпустить
вручную («Осуществить релиз»), если не стоит автоматический выпуск.

## 5. Манифест обновлений `update.json`

Файл в корне репозитория. Приложение читает его **из ветки `main`**: с GitHub,
а при ошибке — через jsDelivr. Скачивает при открытии, но не чаще раза в 3 часа.

```json
{
  "appstore":   { "latest": "2.3.0", "minimum": "2.0.0", "notes": "Поиск по преподавателям" },
  "testflight": { "latest": "2.3.0", "latestBuild": 40, "minimum": "2.0.0", "minimumBuild": 0 }
}
```

Источник установки приложение определяет само: TestFlight читает только
`testflight`, App Store — только `appstore`. В App Store номер сборки не
сравнивается, в TestFlight сравнивается версия, а затем сборка.

| Поле | Что значит | Что увидит пользователь |
|---|---|---|
| `latest` (+ `latestBuild`) | последняя версия, **уже доступная** в этом канале | версия ниже — лист «Вышла версия», точка на аватаре и строка в аккаунте |
| `minimum` (+ `minimumBuild`) | самая старая версия, которая ещё работает | версия ниже — экран «Нужно обновить» поверх всего, закрыть нельзя |
| `notes` | одна-три строки о главном, по желанию | блок «Что нового» на листе |

Лист «Вышла версия» показывается при открытии приложения. После «Позже» он
вернётся через 3 дня, а о более новой версии — сразу.

### Когда менять

- **Сборка стала доступна в TestFlight** (обработка завершена, сборка в группе,
  бета-ревью пройдено) → `testflight.latest` и `latestBuild`, `notes`.
- **Версия вышла в App Store** (нажат релиз и она открывается по ссылке) →
  `appstore.latest`, `notes`.
- **Старые версии сломались** (ЛК поменял API, старая логика портит данные) →
  `minimum` (+ `minimumBuild`) в обоих каналах, но только после того, как
  исправленная версия доступна в канале. Иначе людей заблокирует без выхода.

Не поднимай `latest` раньше времени: человек нажмёт «Обновить» и увидит в
TestFlight или App Store свою же версию.

### Как выложить

Правка `update.json` — PR в `main`, отдельно или вместе с PR номера сборки, но
**влить его только когда сборка уже доступна** (см. «Когда менять»).

После влития GitHub отдаёт новый файл через несколько минут. jsDelivr может
кэшировать до 12 часов. Он нужен только как запасной путь, но кэш можно сбросить:

```bash
curl -s https://purge.jsdelivr.net/gh/ranepa-unofficial/ranepa-sync-ios@main/update.json
```

Проверить, что отдаётся:

```bash
curl -s https://raw.githubusercontent.com/ranepa-unofficial/ranepa-sync-ios/main/update.json
```

### Проверка экранов без публикации

В отладочной сборке источник и манифест задаются аргументами запуска
(трёхчасовой интервал при этом не действует):

```bash
xcrun simctl launch --terminate-running-process booted com.qteb.ranepaTimetable \
  -UPDATE_SOURCE testflight \
  -UPDATE_MANIFEST '{"testflight":{"latest":"2.3.0","latestBuild":40,"minimum":"2.0.0","notes":"Что нового"}}'
```

`-UPDATE_SOURCE appstore` и `"minimum"` выше текущей версии — экран «Нужно обновить».

## Чек-лист

- [ ] `CURRENT_PROJECT_VERSION` (+ `MARKETING_VERSION`) подняты, PR сборки влит
- [ ] Сборка загружена и обработана
- [ ] What to Test заполнено, сборка во внешней группе
- [ ] `update.json`: `testflight.latest` / `latestBuild` — после того, как сборка доступна
- [ ] `update.json`: `appstore.latest` — после выпуска в App Store
- [ ] `minimum` поднят, только если старые версии действительно не работают
