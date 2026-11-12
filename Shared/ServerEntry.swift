/// Через что режимы «Умный» и «Весь трафик» ходят на сервер.
enum ServerEntry: String, CaseIterable {
    case reality   // VLESS Reality поверх TCP: снаружи выглядит как обычный HTTPS
    case hysteria  // Hysteria2 поверх UDP

    var title: String {
        switch self {
        case .reality: return "VLESS Reality (TCP)"
        case .hysteria: return "Hysteria2 (UDP)"
        }
    }
}
