---
name: ios-simulator
description: Проверка iOS-приложения в симуляторе — демо-режим без входа в ЛК, скриншоты с Dynamic Island, запись и раскадровка анимаций, iPhone Duo в разных положениях через Device Hub, поломки симулятора после обновления Xcode. Использовать, когда просят «проверь в симуляторе», «посмотри на iPhone Duo / в разложенном виде», «проверь анимацию», или симулятор и тесты не запускаются.
---

# Проверка в симуляторе

## Демо-режим

- **Вход:** на приветственном экране долгое нажатие (~1,5 с) на иконку приложения.
- **Изменения:** каждое «потянуть вниз» переключает демо-ревизию — у пары следующего дня меняется аудитория. Так вызывается баннер изменений.
- Первый запуск после установки может несколько секунд быть белым — это нормально.

## Скриншоты и анимации

- `xcrun simctl io <udid> screenshot --mask=black f.png` — только с `--mask=black` на снимке есть Dynamic Island.
- **Анимации — только по видео**, серия скриншотов идёт с шагом ~0,3 с:
  ```bash
  xcrun simctl io <udid> recordVideo --mask=black --force rec.mov &   # жест, затем kill -INT
  ffmpeg -loglevel error -i rec.mov -vf "fps=12,crop=1206:520:0:0,scale=201:-1,tile=8x9" -frames:v 1 sheet.png
  ```
  Раскадровку смотри через Read. `sips -c` режет только по центру — для верхней части кадра используй `crop`.

## iPhone Duo

- Только симулятор iOS 27.1+, модель `iPhone19,4`. Положения Closed / Partially Open / Open переключаются **только в приложении Device Hub** — `simctl` сгиб не эмулирует. Через управление компьютером проси доступ к Device Hub (Xcode как IDE даётся лишь «только клики»).
- Экраны: `xcrun simctl io <udid> enumerate`; снимок нужного — `screenshot --display=<UUID порта>`.
- Что меняется: таб-бар и тулбары справа вертикально; горизонтальные `ScrollView` залезают под боковую safe area (лечится `clipHorizontally()` из `Pagers.swift`); внутренний экран — regular width, включаются iPad-раскладки.
- Решено не трогать: сетка недели вокруг сгиба, отступ заголовка на внутреннем экране, переносы в узких колонках.

## Когда симулятор сломан

- «CoreSimulator is out of date» после обновления Xcode — пользователь сам вводит `sudo xcodebuild -runFirstLaunch` (готово, когда `xcodebuild -checkFirstLaunchStatus` возвращает 0). Симуляторы пересоздаются с новыми UDID, вход в ЛК на них пропадает — предупреди.
- «The test runner hung before establishing connection» — подвис симулятор, не код: `xcrun simctl shutdown all` и свежий симулятор.
- Новая платформа — `xcodebuild -downloadPlatform iOS` (8–10 ГБ), спроси заранее.
- ID модели: `modelIdentifier` в `/Library/Developer/CoreSimulator/Profiles/DeviceTypes/<name>.simdevicetype/Contents/Resources/profile.plist`; в приложении — `SIMULATOR_MODEL_IDENTIFIER`.

## Отчёт

Что проверено, на каком устройстве и iOS, и что **не** проверено — фоновые сценарии (обновление, Live Activity с оповещением) в симуляторе не воспроизводятся, их проверяют в TestFlight.
