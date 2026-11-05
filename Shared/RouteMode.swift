import Foundation

/// Режим маршрутизации. Общий для приложения и туннеля.
enum RouteMode: String, CaseIterable {
    case smart   // российское напрямую, остальное через VPN
    case global  // всё через VPN

    var title: String {
        switch self {
        case .smart: return "Умный"
        case .global: return "Весь трафик"
        }
    }

    var caption: String {
        switch self {
        case .smart: return "РФ напрямую"
        case .global: return "Всё через VPN"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "Российские сайты и банки идут напрямую, остальное через VPN"
        case .global: return "Весь трафик идёт через VPN"
        }
    }

    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .global: return "globe"
        }
    }
}
