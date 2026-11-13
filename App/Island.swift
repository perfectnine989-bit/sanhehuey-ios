import ActivityKit
import Foundation

/// Управляет Live Activity (Dynamic Island + экран блокировки).
@MainActor
enum Island {
    /// true, пока VPN переключают кнопкой из острова: тогда выключенный остров остаётся как пульт.
    static var viaIsland = false

    static func push(phase: Int, since: Date?, mode: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = VPNActivityAttributes.ContentState(phase: phase, since: since, mode: mode)
        let current = Activity<VPNActivityAttributes>.activities.first

        if phase == 0 {
            guard let current else { return }
            if viaIsland {
                // Остаётся в острове с кнопкой «Подключить», через 15 минут помечается устаревшим
                await current.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(900)))
            } else {
                await current.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
            return
        }

        if let current {
            await current.update(ActivityContent(state: state, staleDate: nil))
        } else {
            // Запустить можно только из открытого приложения; в фоне система откажет, это не ошибка
            _ = try? Activity<VPNActivityAttributes>.request(
                attributes: VPNActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        }
    }

    static func sync(phase: Int, since: Date?, mode: String) {
        Task { await push(phase: phase, since: since, mode: mode) }
    }
}
