import CryptoKit
import SwiftUI

// MARK: - Хранилище

enum WarpStore {
    private static let defaults = UserDefaults.standard

    /// Свой ключ (получен в приложении) либо вшитый при сборке.
    static var account: WarpAccount? {
        if let own = WarpAccount.from(json: defaults.string(forKey: "warp.account") ?? "") { return own }
        return WarpAccount.from(json: WarpBaked.json)
    }

    static func saveAccount(_ account: WarpAccount) {
        defaults.set(account.json, forKey: "warp.account")
    }

    static var enabled: Bool {
        get { defaults.object(forKey: "warp.on") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "warp.on") }
    }

    /// Вход запоминается отдельно для Wi-Fi и мобильной сети.
    static func endpoint(_ kind: NetworkKind) -> WarpEndpoint {
        WarpEndpoint(id: defaults.string(forKey: "warp.ep." + kind.rawValue) ?? "") ?? WarpEndpoint.candidates[0]
    }

    static func save(_ endpoint: WarpEndpoint, for kind: NetworkKind) {
        defaults.set(endpoint.id, forKey: "warp.ep." + kind.rawValue)
    }
}

// MARK: - Получение ключа у Cloudflare

enum WarpAPI {
    struct Failure: LocalizedError {
        let text: String
        var errorDescription: String? { text }
    }

    static func register() async throws -> WarpAccount {
        var raw = [UInt8](Curve25519.KeyAgreement.PrivateKey().rawRepresentation)
        raw[0] &= 248
        raw[31] &= 127
        raw[31] |= 64
        let key = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(raw))
        let privateKey = Data(raw).base64EncodedString()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()

        guard let url = URL(string: "https://api.cloudflareclient.com/v0a2158/reg") else {
            throw Failure(text: "неверный адрес")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("okhttp/3.12.1", forHTTPHeaderField: "User-Agent")
        request.setValue("a-6.10-2158", forHTTPHeaderField: "CF-Client-Version")
        let body: [String: Any] = [
            "key": publicKey,
            "install_id": "",
            "fcm_token": "",
            "tos": ISO8601DateFormatter().string(from: Date()),
            "model": "PC",
            "serial_number": "",
            "locale": "en_US",
            "type": "Android"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let config = root["config"] as? [String: Any],
              let peers = config["peers"] as? [[String: Any]],
              let peerKey = peers.first?["public_key"] as? String,
              let interface = config["interface"] as? [String: Any],
              let addresses = interface["addresses"] as? [String: Any],
              let v4 = addresses["v4"] as? String
        else {
            throw Failure(text: "Cloudflare ответил кодом \(code)")
        }
        let v6 = addresses["v6"] as? String ?? ""
        var reserved: [Int] = [0, 0, 0]
        if let clientID = config["client_id"] as? String, let bytes = Data(base64Encoded: clientID), bytes.count >= 3 {
            reserved = bytes.prefix(3).map { Int($0) }
        }
        return WarpAccount(privateKey: privateKey, peerKey: peerKey, v4: v4, v6: v6, reserved: reserved)
    }
}

// MARK: - Проверка входов

struct WarpResult: Identifiable {
    let id = UUID()
    let endpoint: WarpEndpoint
    let ai: Bool
    let telegram: Bool
    let time: Double
    let loc: String

    var alive: Bool { ai || telegram }
    var score: Int { (ai ? 0 : 2) + (telegram ? 0 : 1) }

    var line: String {
        var text = endpoint.id + "  ИИ " + (ai ? "да" : "нет") + " · TG " + (telegram ? "да" : "нет")
        if alive { text += " · \(Int(time * 1000)) мс" }
        if !loc.isEmpty { text += " · " + loc }
        return text
    }
}

@MainActor
final class WarpCenter: ObservableObject {
    static let shared = WarpCenter()

    @Published var hasAccount = WarpStore.account != nil
    @Published var enabled = WarpStore.enabled
    @Published var running = false
    @Published var progress = ""
    @Published var summary: String?
    @Published var results: [WarpResult] = []

    func setEnabled(_ value: Bool, vpn: VPNManager) async {
        WarpStore.enabled = value
        enabled = value
        if vpn.isOn, vpn.mode == .direct { _ = await vpn.restartAndWait() }
    }

    func register(vpn: VPNManager) async {
        guard !running else { return }
        running = true
        progress = "Получаю ключ…"
        summary = nil
        do {
            let account = try await WarpAPI.register()
            WarpStore.saveAccount(account)
            WarpStore.enabled = true
            hasAccount = true
            enabled = true
            summary = "Ключ WARP получен. Нажми «Проверить», чтобы найти рабочий вход для этой сети."
            if vpn.isOn, vpn.mode == .direct { _ = await vpn.restartAndWait() }
        } catch {
            summary = "Не удалось получить ключ: \(error.localizedDescription). Попробуй на другой сети или при включённом обходе."
        }
        running = false
    }

    /// Перебирает входы WARP: поднимает туннель с каждым и смотрит, открываются ли ChatGPT и Telegram.
    func run(vpn: VPNManager) async {
        guard !running, !StrategyTuner.shared.running, vpn.mode == .direct, WarpStore.account != nil else { return }
        running = true
        summary = nil
        results = []
        WarpStore.enabled = true
        enabled = true
        let kind = NetworkWatcher.shared.kind
        vpn.quiet = true

        let list = WarpEndpoint.candidates
        for (index, endpoint) in list.enumerated() {
            progress = "Вход \(index + 1) из \(list.count): \(endpoint.id)"
            vpn.warpEndpointOverride = endpoint
            let up = await vpn.restartAndWait()
            if !up {
                results.append(WarpResult(endpoint: endpoint, ai: false, telegram: false, time: 0, loc: ""))
                continue
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            results.append(await Self.probe(endpoint))
        }

        let alive = results.filter { $0.alive }
        let best = alive.min { a, b in
            if a.score != b.score { return a.score < b.score }
            return a.time < b.time
        }
        let place = kind == .wifi ? "Wi-Fi" : "мобильной сети"
        if let best {
            WarpStore.save(best.endpoint, for: kind)
            var text = "Выжило \(alive.count) из \(list.count). Лучший вход для \(place): \(best.endpoint.id)."
            if !best.loc.isEmpty {
                text += " ChatGPT видит страну \(best.loc)."
                if best.loc == "RU" { text += " Это Россия, ИИ могут отказать." }
            }
            summary = text
        } else {
            summary = "На \(place) WARP не пробился ни через один вход из \(list.count): здесь режут сам протокол WireGuard."
        }

        vpn.warpEndpointOverride = nil
        progress = "Включаю лучший…"
        _ = await vpn.restartAndWait()
        vpn.quiet = false
        running = false
        Haptics.connected()
    }

    private static func probe(_ endpoint: WarpEndpoint) async -> WarpResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 7
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        async let aiTask = fetch(session, "https://chatgpt.com/cdn-cgi/trace")
        async let tgTask = fetch(session, "https://api.telegram.org/")
        let ai = await aiTask
        let tg = await tgTask

        var loc = ""
        if let text = ai?.text {
            for row in text.split(separator: "\n") where row.hasPrefix("loc=") {
                loc = String(row.dropFirst(4))
            }
        }
        let time = ai?.time ?? tg?.time ?? 0
        return WarpResult(endpoint: endpoint, ai: ai != nil, telegram: tg != nil, time: time, loc: loc)
    }

    private static func fetch(_ session: URLSession, _ address: String) async -> (text: String, time: Double)? {
        guard let url = URL(string: address) else { return nil }
        let start = Date()
        do {
            let (data, response) = try await session.data(from: url)
            guard response is HTTPURLResponse else { return nil }
            let text = String(data: data.prefix(2048), encoding: .utf8) ?? ""
            return (text, Date().timeIntervalSince(start))
        } catch {
            return nil
        }
    }
}

// MARK: - Карточка на главном экране (только режим «Без сервера»)

struct WarpCard: View {
    @EnvironmentObject var vpn: VPNManager
    @ObservedObject private var center = WarpCenter.shared
    @ObservedObject private var tuner = StrategyTuner.shared
    let palette: Palette

    private var busy: Bool { center.running || tuner.running }

    private var statusLine: String {
        if center.running { return center.progress }
        if !center.hasAccount { return "Ключ не получен" }
        if !center.enabled { return "Выключен" }
        return "Вход " + WarpStore.endpoint(NetworkWatcher.shared.kind).id
    }

    private var buttonTitle: String {
        if center.running { return "Проверка…" }
        return center.hasAccount ? "Проверить" : "Получить"
    }

    private var shownResults: [WarpResult] {
        Array(center.results.filter { $0.alive }.sorted { $0.score == $1.score ? $0.time < $1.time : $0.score < $1.score }.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "cloud")
                    .font(.system(size: 15))
                    .foregroundColor(palette.light)

                Menu {
                    if center.hasAccount {
                        Button(center.enabled ? "Выключить WARP" : "Включить WARP") {
                            Task { await center.setEnabled(!center.enabled, vpn: vpn) }
                        }
                    }
                    Button("Получить новый ключ") {
                        Task { await center.register(vpn: vpn) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("WARP · ИИ И TELEGRAM")
                            .font(Theme.label(11))
                            .tracking(2)
                            .foregroundColor(Theme.goldDim)
                        Text(statusLine)
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .disabled(busy)

                Spacer(minLength: 6)

                Button {
                    Task {
                        if center.hasAccount {
                            await center.run(vpn: vpn)
                        } else {
                            await center.register(vpn: vpn)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if center.running { ProgressView().tint(Theme.text) }
                        Text(buttonTitle)
                    }
                    .font(Theme.title(13))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .liquidGlass(Capsule(), tint: palette.main.opacity(0.3), interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }

            if let summary = center.summary, !center.running {
                Text(summary)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(shownResults) { result in
                    Text(result.line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(14)
        .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Color.black.opacity(0.22))
    }
}
