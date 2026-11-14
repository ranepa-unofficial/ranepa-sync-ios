import UIKit

/// Ссылка на бота поддержки. В параметре start бот получает версию приложения,
/// систему и модель, например `app-2-2-0-30_ios-27-0-1_iphone-17-pro-max`.
/// Тот же формат будет у Android-версии: `app-1-0-0-1_android-16_pixel-9`.
enum SupportLink {
    static let bot = "ranepa_sync_robot"
    /// Telegram принимает в start не больше 64 символов: латиницу, цифры, `_` и `-`.
    static let maxLength = 64

    static var url: URL {
        let info = Bundle.main.infoDictionary
        let device = UIDevice.current
        let isMac = ProcessInfo.processInfo.isiOSAppOnMac
        let start = startParameter(
            app: "\(info?["CFBundleShortVersionString"] ?? "")-\(info?["CFBundleVersion"] ?? "")",
            os: isMac ? "macos" : device.userInterfaceIdiom == .pad ? "ipados" : "ios",
            osVersion: device.systemVersion,
            model: isMac ? "mac" : modelName(machineIdentifier)
        )
        return URL(string: "https://t.me/\(bot)?start=\(start)")!
    }

    /// Версии приложения и системы сохраняются всегда, при нехватке места укорачивается модель.
    static func startParameter(app: String, os: String, osVersion: String, model: String) -> String {
        let head = "app-\(slug(app))_\(slug(os))-\(slug(osVersion))"
        let room = maxLength - head.count - 1
        let device = slug(String(slug(model).prefix(max(room, 0))))
        return device.isEmpty ? String(head.prefix(maxLength)) : "\(head)_\(device)"
    }

    /// Строчные буквы и цифры, всё остальное — одиночные дефисы.
    static func slug(_ text: String) -> String {
        text.lowercased()
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .joined(separator: "-")
    }

    /// Название модели по коду вроде `iPhone18,2`. В симуляторе — модель симулятора
    /// с пометкой `simulator`, у неизвестной модели — сам код.
    static func modelName(_ identifier: String) -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return knownName(simulated) + "-simulator"
        }
        return knownName(identifier)
    }

    private static func knownName(_ identifier: String) -> String {
        models[identifier] ?? slug(identifier)
    }

    static var machineIdentifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    /// Устройства с поддержкой iOS 26 и iPadOS 26. Коды — из списка
    /// https://gist.github.com/adamawolf/3048717, названия — маркетинговые.
    /// Новую модель достаточно дописать сюда; до этого бот получит её код.
    static let models: [String: String] = [
        "iPhone12,1": "iphone-11", "iPhone12,3": "iphone-11-pro", "iPhone12,5": "iphone-11-pro-max",
        "iPhone12,8": "iphone-se-2",
        "iPhone13,1": "iphone-12-mini", "iPhone13,2": "iphone-12",
        "iPhone13,3": "iphone-12-pro", "iPhone13,4": "iphone-12-pro-max",
        "iPhone14,4": "iphone-13-mini", "iPhone14,5": "iphone-13",
        "iPhone14,2": "iphone-13-pro", "iPhone14,3": "iphone-13-pro-max", "iPhone14,6": "iphone-se-3",
        "iPhone14,7": "iphone-14", "iPhone14,8": "iphone-14-plus",
        "iPhone15,2": "iphone-14-pro", "iPhone15,3": "iphone-14-pro-max",
        "iPhone15,4": "iphone-15", "iPhone15,5": "iphone-15-plus",
        "iPhone16,1": "iphone-15-pro", "iPhone16,2": "iphone-15-pro-max",
        "iPhone17,3": "iphone-16", "iPhone17,4": "iphone-16-plus",
        "iPhone17,1": "iphone-16-pro", "iPhone17,2": "iphone-16-pro-max", "iPhone17,5": "iphone-16e",
        "iPhone18,3": "iphone-17", "iPhone18,4": "iphone-air",
        "iPhone18,1": "iphone-17-pro", "iPhone18,2": "iphone-17-pro-max", "iPhone18,5": "iphone-17e",
        "iPhone19,4": "iphone-duo",

        "iPad11,6": "ipad-8", "iPad11,7": "ipad-8",
        "iPad12,1": "ipad-9", "iPad12,2": "ipad-9",
        "iPad13,18": "ipad-10", "iPad13,19": "ipad-10",
        "iPad15,7": "ipad-a16", "iPad15,8": "ipad-a16",
        "iPad11,1": "ipad-mini-5", "iPad11,2": "ipad-mini-5",
        "iPad14,1": "ipad-mini-6", "iPad14,2": "ipad-mini-6",
        "iPad16,1": "ipad-mini-a17-pro", "iPad16,2": "ipad-mini-a17-pro",
        "iPad11,3": "ipad-air-3", "iPad11,4": "ipad-air-3",
        "iPad13,1": "ipad-air-4", "iPad13,2": "ipad-air-4",
        "iPad13,16": "ipad-air-5", "iPad13,17": "ipad-air-5",
        "iPad14,8": "ipad-air-11-m2", "iPad14,9": "ipad-air-11-m2",
        "iPad14,10": "ipad-air-13-m2", "iPad14,11": "ipad-air-13-m2",
        "iPad15,3": "ipad-air-11-m3", "iPad15,4": "ipad-air-11-m3",
        "iPad15,5": "ipad-air-13-m3", "iPad15,6": "ipad-air-13-m3",
        "iPad16,8": "ipad-air-11-m4", "iPad16,9": "ipad-air-11-m4",
        "iPad16,10": "ipad-air-13-m4", "iPad16,11": "ipad-air-13-m4",
        "iPad8,1": "ipad-pro-11-1", "iPad8,2": "ipad-pro-11-1", "iPad8,3": "ipad-pro-11-1", "iPad8,4": "ipad-pro-11-1",
        "iPad8,9": "ipad-pro-11-2", "iPad8,10": "ipad-pro-11-2",
        "iPad13,4": "ipad-pro-11-3", "iPad13,5": "ipad-pro-11-3", "iPad13,6": "ipad-pro-11-3", "iPad13,7": "ipad-pro-11-3",
        "iPad14,3": "ipad-pro-11-4", "iPad14,4": "ipad-pro-11-4",
        "iPad16,3": "ipad-pro-11-m4", "iPad16,4": "ipad-pro-11-m4",
        "iPad8,5": "ipad-pro-12-9-3", "iPad8,6": "ipad-pro-12-9-3", "iPad8,7": "ipad-pro-12-9-3", "iPad8,8": "ipad-pro-12-9-3",
        "iPad8,11": "ipad-pro-12-9-4", "iPad8,12": "ipad-pro-12-9-4",
        "iPad13,8": "ipad-pro-12-9-5", "iPad13,9": "ipad-pro-12-9-5", "iPad13,10": "ipad-pro-12-9-5", "iPad13,11": "ipad-pro-12-9-5",
        "iPad14,5": "ipad-pro-12-9-6", "iPad14,6": "ipad-pro-12-9-6",
        "iPad16,5": "ipad-pro-13-m4", "iPad16,6": "ipad-pro-13-m4",
    ]
}
