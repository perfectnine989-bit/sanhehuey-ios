/// Через что режимы «Умный» и «Весь трафик» ходят на сервер.
enum ServerEntry: String, CaseIterable {
    case cdn       // VLESS поверх WebSocket через Cloudflare: переживает бан IP сервера
    case reality   // VLESS Reality поверх TCP: снаружи выглядит как обычный HTTPS
    case hysteria  // Hysteria2 поверх UDP

    var title: String {
        switch self {
        case .cdn: return "CDN · Cloudflare (рекомендуется)"
        case .reality: return "VLESS Reality (TCP)"
        case .hysteria: return "Hysteria2 (UDP)"
        }
    }

    /// Строка «Протокол» в профиле.
    var protocolName: String {
        switch self {
        case .cdn: return "VLESS · CDN"
        case .reality: return "VLESS Reality"
        case .hysteria: return "Hysteria2"
        }
    }

    /// Строка «Маскировка» в профиле.
    var masking: String {
        switch self {
        case .cdn: return "WebSocket · TLS · Cloudflare"
        case .reality: return "Reality · TCP"
        case .hysteria: return "Salamander · UDP"
        }
    }
}
