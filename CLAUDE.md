# Расписание студента — iOS

SwiftUI, iOS 26+, проект генерируется XcodeGen (`app/project.yml`). Как всё устроено — [`docs/`](docs/README.md). Android-версия — `~/Developer/ranepa-unofficial/ranepa-sync-android`.

## Правила

- `main` защищён: всё через PR, вливать `gh pr merge N --squash --admin --delete-branch` только после «ок» пользователя.
- В коммитах и PR — без Co-Authored-By и любой атрибуции ИИ.
- Репозиторий публичный: ключи App Store Connect, Issuer/Key ID и `~/.appstoreconnect` не коммитить и не цитировать.
- Версию выбирает пользователь, номер сборки — всегда +1.
- Новые экраны и крупные изменения вида — сначала макет в Claude Design и согласование. Тексты — на русском.
- Меняется, что уходит в сеть, — правь `PRIVACY.md` в том же PR.

## Скиллы (`.claude/skills`)

| Скилл | Когда |
|---|---|
| `ios-release` | сборка, TestFlight, App Store Connect API, `update.json` |
| `ios-analytics` | события TelemetryDeck и проверка сигналов |
| `ios-simulator` | демо-режим, скриншоты, анимации, iPhone Duo, поломки симулятора |
| `ios-dynamic-island` | Live Activity, остров, баннер изменений |
| `ios-to-android` | промпт для переноса функции в Android |
