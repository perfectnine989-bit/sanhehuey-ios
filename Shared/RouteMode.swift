import Foundation

/// Режим маршрутизации. Общий для приложения и туннеля.
enum RouteMode: String, CaseIterable {
    case smart   // российское напрямую, остальное через VPN
    case global  // всё через VPN
    case direct  // без сервера: обход DPI прямо на телефоне

    var title: String {
        switch self {
        case .smart: return "Умный"
        case .global: return "Весь трафик"
        case .direct: return "Без сервера"
        }
    }

    var caption: String {
        switch self {
        case .smart: return "РФ напрямую"
        case .global: return "Всё через VPN"
        case .direct: return "Обход на месте"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "Российские сайты и банки идут напрямую, остальное через VPN"
        case .global: return "Весь трафик идёт через VPN"
        case .direct: return "Без сервера, обход прямо на телефоне. Открывает не всё: если сайт не грузится, включи «Умный»"
        }
    }

    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .global: return "globe"
        case .direct: return "bolt"
        }
    }
}

/// Стратегии обхода DPI для режима «Без сервера».
/// В ядре sing-box 1.12 есть два механизма: разрезание ClientHello на TLS-записи
/// и на TCP-сегменты. Стратегии комбинируют механизм и охват (все сайты или только известные заблокированные).
enum DPIStrategy: String, CaseIterable {
    case recordAll       // TLS-записи, для всех нероссийских сайтов
    case recordBlocked   // TLS-записи, только для известных заблокированных
    case segmentAll      // TCP-сегменты, для всех нероссийских сайтов
    case segmentBlocked  // TCP-сегменты, только для известных заблокированных
    case dnsOnly         // без фрагментации: только шифрованный DNS и запрет QUIC

    var title: String {
        switch self {
        case .recordAll: return "Записи · все"
        case .recordBlocked: return "Записи · точечно"
        case .segmentAll: return "Сегменты · все"
        case .segmentBlocked: return "Сегменты · точечно"
        case .dnsOnly: return "Только DNS"
        }
    }

    /// Параметры фрагментации для правила маршрута sing-box (nil — без фрагментации).
    var fragment: [String: Any]? {
        switch self {
        case .recordAll, .recordBlocked:
            return ["tls_record_fragment": true]
        case .segmentAll, .segmentBlocked:
            return ["tls_fragment": true, "tls_fragment_fallback_delay": "100ms"]
        case .dnsOnly:
            return nil
        }
    }

    var onlyBlocked: Bool { self == .recordBlocked || self == .segmentBlocked }
}
