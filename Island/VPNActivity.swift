import ActivityKit
import AppIntents
import Foundation

/// Данные для Dynamic Island и плашки на экране блокировки. Общие для приложения и виджета.
struct VPNActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 0 — выключено, 1 — подключение, 2 — подключено
        var phase: Int
        /// Когда подключились (для таймера)
        var since: Date?
        /// Название режима
        var mode: String
    }
}

/// Мост от кнопки в острове к приложению. Заполняется при запуске приложения.
enum IslandBridge {
    static var toggle: (@MainActor () async -> Void)?
}

/// Кнопка «Подключить / Отключить» в острове. Выполняется в процессе приложения, без его открытия.
struct ToggleVPNIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Переключить VPN"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await IslandBridge.toggle?()
        return .result()
    }
}
