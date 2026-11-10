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
/// Почти все работают через встроенный движок ByeDPI (локальный прокси внутри расширения),
/// «Записи (лёгкий)» — средствами самого sing-box, без движка.
enum DPIStrategy: String, CaseIterable {
    case auto       // авто-цепочка: при неудаче сам переходит к следующему приёму и запоминает удачный
    case disorder   // часть ClientHello с TTL=1, досылается после второй: DPI видит пакеты не по порядку
    case oob        // разрез + «срочный» байт, который DPI учитывает, а сайт нет
    case disoob     // disorder + OOB
    case sniSplit   // разрез внутри имени сайта + disorder
    case record     // лёгкий: разрез на TLS-записи средствами sing-box
    case custom     // своя строка параметров ByeDPI

    var title: String {
        switch self {
        case .auto: return "Авто-цепочка"
        case .disorder: return "Disorder"
        case .oob: return "OOB"
        case .disoob: return "DisOOB"
        case .sniSplit: return "Разрез по SNI"
        case .record: return "Записи (лёгкий)"
        case .custom: return "Своя стратегия"
        }
    }

    /// Параметры движка ByeDPI. nil — стратегия работает без движка.
    func engineArgs(custom: String) -> String? {
        switch self {
        case .auto: return "-d1 -r1+s -At,s -o1 -r1+s -At,s -q1+s -At,s -s1+s -d3+s -r1+s"
        case .disorder: return "-d1 -r1+s"
        case .oob: return "-o1 -r1+s"
        case .disoob: return "-q1+s"
        case .sniSplit: return "-s1+s -d3+s"
        case .record: return nil
        case .custom:
            let text = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "-d1 -r1+s" : text
        }
    }

    /// Фрагментация средствами sing-box (только для лёгкой стратегии).
    var fragment: [String: Any]? {
        self == .record ? ["tls_record_fragment": true] : nil
    }
}
