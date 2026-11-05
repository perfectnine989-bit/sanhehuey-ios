import Foundation

/// Режим маршрутизации. Общий для приложения и туннеля.
enum RouteMode: String, CaseIterable {
    case smart   // российское напрямую, остальное через VPN
    case global  // всё через VPN

    var title: String {
        switch self {
        case .smart: return "Умный"
        case .global: return "Всё через VPN"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "Российские сайты и банки идут напрямую"
        case .global: return "Весь трафик идёт через VPN"
        }
    }
}
