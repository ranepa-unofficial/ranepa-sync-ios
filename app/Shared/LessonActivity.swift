import ActivityKit
import Foundation

/// Live Activity с идущей или ближайшей парой. Запускает приложение
/// (ios/Runner/LiveActivityBridge.swift), показывает расширение виджета.
@available(iOS 16.2, *)
struct LessonActivityAttributes: ActivityAttributes {
    struct Lesson: Codable, Hashable {
        let title: String
        let kind: String
        /// «1 - 2317».
        let room: String
        /// Полный адрес аудитории для развёрнутого вида.
        let fullRoom: String
        let start: Date
        let end: Date

        /// Открыть приложение на этой паре.
        var url: URL { lessonURL(start) }

        /// Для свёрнутого Dynamic Island: «1 - 2317» → «2317».
        var compactRoom: String {
            if room == "Дистанционно" { return "СДО" }
            if let dash = room.range(of: " - ", options: .backwards) {
                return String(room[dash.upperBound...])
            }
            return room
        }
    }

    struct ContentState: Codable, Hashable {
        /// Идущая пара или ближайшая, если сейчас перемена.
        let lesson: Lesson
        /// Следующая после неё сегодня.
        let next: Lesson?
        /// lesson уже идёт. Активность устаревает к концу идущей пары или
        /// к началу ближайшей — по isCurrent расширение понимает, что
        /// показать после этого, если приложение не успело обновить её.
        let isCurrent: Bool
        /// Что только что изменилось у идущей или ближайшей пары. Есть
        /// только в обновлении, которое раскрывает остров; следующее
        /// обновление его убирает.
        var change: Change? = nil
    }

    /// «Аудитория изменилась: 2 - 2016 → 5 - 301».
    struct Change: Codable, Hashable {
        enum Kind: String, Codable { case room, time, cancelled }

        let kind: Kind
        /// Пара, как она была: название, тип и время для подзаголовка.
        let lesson: Lesson
        /// Было и стало: аудитории или время начала. У отмены — nil.
        let old: String?
        let new: String?

        var headline: String {
            switch kind {
            case .room: "Аудитория изменилась"
            case .time: "Пара перенесена"
            case .cancelled: "Пара отменена"
            }
        }
    }
}

/// ranepa://lesson?start=<секунды> — приложение откроет день этой пары
/// и её карточку (lib/services/lesson_links.dart).
func lessonURL(_ start: Date) -> URL {
    URL(string: "ranepa://lesson?start=\(Int(start.timeIntervalSince1970))")!
}
