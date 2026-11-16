---
name: ios-dynamic-island
description: Live Activity пары и Dynamic Island — что можно и нельзя на острове, оповещение об изменении пары, баннер, «вытекающий» из острова, и геометрия острова по моделям iPhone. Использовать при любой доработке Live Activity, Dynamic Island, баннера изменений или вопросах «можно ли на острове…».
---

# Dynamic Island и Live Activity

## Где код

- `app/Shared/LessonActivity.swift` — `LessonActivityAttributes`, `ContentState`, `Change`.
- `app/RanepaWidget/LessonLiveActivity.swift` — компактный, минимальный и развёрнутый вид, экран блокировки, `ChangeView`.
- `app/Ranepa/Services/Outputs.swift` — `LiveActivityPlan`, `change(from:to:now:)`, `LiveActivities.update`.
- `app/Ranepa/Views/IslandBanner.swift` — `Island` (геометрия), `IslandBanner`, `Goo`.
- Тесты: `app/RanepaTests/LiveActivityPlanTests.swift`.

## Ограничения iOS

- Нажатие открывает приложение по `widgetURL` (`ranepa://lesson?start=`), долгое нажатие — развёрнутый вид.
- Потянуть остров вниз нельзя: свайп сверху открывает шторку с карточкой экрана блокировки.
- В развёрнутом виде нет прокрутки и жестов — только кнопки и переключатели через App Intents.
- Время — абсолютное («до 12:00»), не отсчёт: без приложения iOS перерисовывает активность ненадёжно.

## Оповещение об изменении пары

- `change` сравнивает `lesson` и `next` с новым расписанием: другая аудитория → `room`, другое время в тот же день → `time`, пары нет → `cancelled`; закончившиеся пары не учитываются.
- Приложение **не** открыто → `activity.update(content, alertConfiguration:)`: остров раскрывается со звуком, без острова — баннер с `changeBody`. В открытом приложении — свой баннер, оповещение не шлём.
- `change` живёт одно обновление.
- В симуляторе не проверить (нужен фоновый запуск) — только TestFlight, так и скажи.

## Баннер из острова

- Остров, «шейка» и капля рисуются в одном `Canvas` с `.alphaThreshold(min: 0.43)` и `.blur(radius: 14)` — фигуры сливаются. Анимируются `drop`, `expand`, `reveal` пружинами с задержками 0 / 0,34 / 0,56 с; свайп вверх (>18 pt) или нажатие втягивает каплю.
- Координат острова система не отдаёт — размеры сняты со снимков симуляторов:

  | Модели | Ширина | Сверху |
  |---|---|---|
  | iPhone 14 Pro – 17 Pro Max, 15/16/17 | 126 | 14 |
  | iPhone Air (`iPhone18,4`) | 126 | 20 |
  | iPhone 18 Pro / Pro Max (`iPhone19,x`) | 95 | 14 |

  Высота везде 37. Без острова (16e, 17e, iPhone Duo, iPad, Mac) и при «Уменьшении движения» — обычный `BannerView`.
- **Новая модель:** `screenshot --mask=black` на белом фоне (скилл `ios-simulator`), измерь чёрную пилюлю, допиши в `Island.frame`.

Цвета типов пар — `kindColor`, иконки — `kindSymbol` (`app/Shared/Lessons.swift`).
