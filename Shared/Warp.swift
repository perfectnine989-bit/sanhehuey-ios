import Foundation

/// Учётка бесплатного Cloudflare WARP. Используется только в режиме «Без сервера»:
/// через неё идут ИИ-сервисы и Telegram, всё остальное остаётся как было.
struct WarpAccount: Codable {
    var privateKey: String
    var peerKey: String
    var v4: String
    var v6: String
    var reserved: [Int]

    var json: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func from(json: String) -> WarpAccount? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        guard let account = try? JSONDecoder().decode(WarpAccount.self, from: data) else { return nil }
        guard !account.privateKey.isEmpty, !account.peerKey.isEmpty, !account.v4.isEmpty else { return nil }
        return account
    }
}

/// Вход в сеть WARP: адрес и UDP-порт. Операторы режут их по-разному, поэтому перебираем.
struct WarpEndpoint: Hashable {
    let host: String
    let port: Int

    var id: String { "\(host):\(port)" }

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    init?(id: String) {
        let parts = id.split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1]), port > 0, port < 65536 else { return nil }
        self.host = String(parts[0])
        self.port = port
    }

    static let candidates: [WarpEndpoint] = [
        WarpEndpoint(host: "162.159.192.1", port: 2408),
        WarpEndpoint(host: "162.159.192.1", port: 500),
        WarpEndpoint(host: "162.159.192.1", port: 4500),
        WarpEndpoint(host: "162.159.192.1", port: 1701),
        WarpEndpoint(host: "162.159.193.5", port: 2408),
        WarpEndpoint(host: "162.159.195.1", port: 4500),
        WarpEndpoint(host: "188.114.96.1", port: 2408),
        WarpEndpoint(host: "188.114.97.1", port: 500),
        WarpEndpoint(host: "188.114.98.1", port: 1701),
        WarpEndpoint(host: "188.114.99.1", port: 4500),
        WarpEndpoint(host: "162.159.192.9", port: 8886),
        WarpEndpoint(host: "188.114.96.3", port: 7559)
    ]
}
