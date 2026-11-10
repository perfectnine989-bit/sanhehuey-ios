import Network
import SwiftUI

// MARK: - Тип сети (стратегия запоминается отдельно для Wi-Fi и мобильной)

enum NetworkKind: String {
    case wifi, cellular
}

final class NetworkWatcher {
    static let shared = NetworkWatcher()
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var current: NetworkKind = .wifi

    var kind: NetworkKind {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wifi = path.availableInterfaces.contains { $0.type == .wifi || $0.type == .wiredEthernet }
            self?.set(wifi ? .wifi : .cellular)
        }
        monitor.start(queue: DispatchQueue(label: "sanhehuey.network"))
    }

    private func set(_ value: NetworkKind) {
        lock.lock()
        current = value
        lock.unlock()
    }
}

enum StrategyStore {
    static func load(_ kind: NetworkKind) -> DPIStrategy {
        DPIStrategy(rawValue: UserDefaults.standard.string(forKey: "dpi." + kind.rawValue) ?? "") ?? .recordAll
    }

    static func save(_ strategy: DPIStrategy, for kind: NetworkKind) {
        UserDefaults.standard.set(strategy.rawValue, forKey: "dpi." + kind.rawValue)
    }
}

// MARK: - Подбор стратегии

struct StrategyResult: Identifiable {
    let id = UUID()
    let strategy: DPIStrategy
    let opened: Int
    let total: Int
    let time: Double
}

@MainActor
final class StrategyTuner: ObservableObject {
    static let shared = StrategyTuner()

    @Published var running = false
    @Published var progress = ""
    @Published var summary: String?
    @Published var results: [StrategyResult] = []

    /// Сайты, которые обычно режут по имени. Считаем «открылся», если сервер вообще ответил по HTTPS.
    static let testURLs = [
        "https://www.youtube.com/generate_204",
        "https://i.ytimg.com/generate_204",
        "https://www.instagram.com/",
        "https://discord.com/",
        "https://x.com/",
        "https://www.linkedin.com/",
        "https://rutracker.org/forum/index.php"
    ]

    func run(vpn: VPNManager) async {
        guard !running else { return }
        running = true
        summary = nil
        results = []
        let kind = NetworkWatcher.shared.kind
        vpn.quiet = true

        let strategies = DPIStrategy.allCases
        for (index, strategy) in strategies.enumerated() {
            progress = "Проверяю \(index + 1) из \(strategies.count): \(strategy.title)"
            vpn.strategyOverride = strategy
            let up = await vpn.restartAndWait()
            if !up {
                results.append(StrategyResult(strategy: strategy, opened: 0, total: Self.testURLs.count, time: 0))
                continue
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            let probe = await Self.probe()
            results.append(StrategyResult(strategy: strategy, opened: probe.opened, total: Self.testURLs.count, time: probe.time))
        }

        // Лучшая: больше всего открывшихся сайтов, при равенстве — быстрее.
        let best = results.max { a, b in
            a.opened != b.opened ? a.opened < b.opened : a.time > b.time
        }
        let place = kind == .wifi ? "Wi-Fi" : "мобильной сети"
        if let best, best.opened > 0 {
            StrategyStore.save(best.strategy, for: kind)
            let seconds = String(format: "%.1f", best.time).replacingOccurrences(of: ".", with: ",")
            summary = "Лучшая для \(place): \(best.strategy.title). Открылось \(best.opened) из \(best.total), в среднем \(seconds) с."
        } else {
            summary = "На этой сети ни одна стратегия не открыла тестовые сайты. Здесь поможет только режим через сервер."
        }

        vpn.strategyOverride = nil
        progress = "Включаю лучшую…"
        _ = await vpn.restartAndWait()
        vpn.quiet = false
        running = false
        Haptics.connected()
    }

    private static func probe() async -> (opened: Int, time: Double) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 7
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        return await withTaskGroup(of: Double?.self) { group in
            for address in testURLs {
                group.addTask {
                    guard let url = URL(string: address) else { return nil }
                    var request = URLRequest(url: url)
                    request.setValue("bytes=0-2047", forHTTPHeaderField: "Range")
                    let start = Date()
                    do {
                        let (_, response) = try await session.data(for: request)
                        guard response is HTTPURLResponse else { return nil }
                        return Date().timeIntervalSince(start)
                    } catch {
                        return nil
                    }
                }
            }
            var opened = 0
            var total = 0.0
            for await value in group {
                if let value {
                    opened += 1
                    total += value
                }
            }
            return (opened, opened > 0 ? total / Double(opened) : 0)
        }
    }
}

// MARK: - Карточка режима на главном экране

struct StrategyCard: View {
    @EnvironmentObject var vpn: VPNManager
    @ObservedObject private var tuner = StrategyTuner.shared
    let palette: Palette

    private var kind: NetworkKind { NetworkWatcher.shared.kind }
    private var current: DPIStrategy { StrategyStore.load(kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .foregroundColor(palette.light)

                Menu {
                    ForEach(DPIStrategy.allCases, id: \.self) { strategy in
                        Button(strategy.title) {
                            StrategyStore.save(strategy, for: kind)
                            if vpn.isOn { Task { _ = await vpn.restartAndWait() } }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("СТРАТЕГИЯ · " + (kind == .wifi ? "WI-FI" : "МОБИЛЬНАЯ"))
                            .font(Theme.label(11))
                            .tracking(2)
                            .foregroundColor(Theme.goldDim)
                        Text(tuner.running ? tuner.progress : current.title)
                            .font(Theme.body(15))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .disabled(tuner.running)

                Spacer(minLength: 6)

                Button {
                    Task { await tuner.run(vpn: vpn) }
                } label: {
                    HStack(spacing: 6) {
                        if tuner.running { ProgressView().tint(Theme.text) }
                        Text(tuner.running ? "Подбор…" : "Подобрать")
                    }
                    .font(Theme.title(13))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .liquidGlass(Capsule(), tint: palette.main.opacity(0.3), interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(tuner.running)
            }

            if let summary = tuner.summary, !tuner.running {
                Text(summary)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Color.black.opacity(0.22))
    }
}
