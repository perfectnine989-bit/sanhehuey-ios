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
        DPIStrategy(rawValue: UserDefaults.standard.string(forKey: "dpi." + kind.rawValue) ?? "") ?? .auto
    }

    static func save(_ strategy: DPIStrategy, for kind: NetworkKind) {
        UserDefaults.standard.set(strategy.rawValue, forKey: "dpi." + kind.rawValue)
    }

    /// Своя строка параметров ByeDPI.
    static var customArgs: String {
        get { UserDefaults.standard.string(forKey: "dpi.custom") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "dpi.custom") }
    }
}

// MARK: - Подбор стратегии

struct StrategyResult: Identifiable {
    let id = UUID()
    let strategy: DPIStrategy
    let opened: Int
    let total: Int
    let time: Double
    let mbps: Double
}

@MainActor
final class StrategyTuner: ObservableObject {
    static let shared = StrategyTuner()

    @Published var running = false
    @Published var progress = ""
    @Published var summary: String?
    @Published var results: [StrategyResult] = []

    /// Сайты, которые обычно режут по имени. «Открылся» — если сервер вообще ответил по HTTPS.
    static let testURLs = [
        "https://www.youtube.com/generate_204",
        "https://i.ytimg.com/generate_204",
        "https://www.instagram.com/",
        "https://discord.com/",
        "https://x.com/",
        "https://www.linkedin.com/",
        "https://rutracker.org/forum/index.php"
    ]

    /// Для замера скорости: главная YouTube и большая картинка YouTube (их душат так же, как видео).
    static let speedURLs = [
        "https://www.youtube.com/",
        "https://i.ytimg.com/vi/aqz-KE-bpKQ/maxresdefault.jpg"
    ]

    func run(vpn: VPNManager) async {
        guard !running else { return }
        running = true
        summary = nil
        results = []
        let kind = NetworkWatcher.shared.kind
        vpn.quiet = true

        let candidates = DPIStrategy.allCases.filter { $0 != .custom || !StrategyStore.customArgs.isEmpty }
        for (index, strategy) in candidates.enumerated() {
            progress = "Проверяю \(index + 1) из \(candidates.count): \(strategy.title)"
            vpn.strategyOverride = strategy
            let up = await vpn.restartAndWait()
            if !up {
                results.append(StrategyResult(strategy: strategy, opened: 0, total: Self.testURLs.count, time: 0, mbps: 0))
                continue
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            let reach = await Self.probe()
            let speed = reach.opened > 0 ? await Self.measureSpeed() : 0
            results.append(StrategyResult(strategy: strategy, opened: reach.opened, total: Self.testURLs.count,
                                          time: reach.time, mbps: speed))
        }

        // Лучшая: больше всего открывшихся, затем выше скорость, затем быстрее отклик.
        let best = results.max { a, b in
            if a.opened != b.opened { return a.opened < b.opened }
            if abs(a.mbps - b.mbps) > 0.5 { return a.mbps < b.mbps }
            return a.time > b.time
        }
        let place = kind == .wifi ? "Wi-Fi" : "мобильной сети"
        if let best, best.opened > 0 {
            StrategyStore.save(best.strategy, for: kind)
            let speed = String(format: "%.1f", best.mbps).replacingOccurrences(of: ".", with: ",")
            summary = "Лучшая для \(place): \(best.strategy.title). Открылось \(best.opened) из \(best.total), скорость YouTube ≈ \(speed) Мбит/с."
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

    private static func session(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    private static func probe() async -> (opened: Int, time: Double) {
        let session = session(timeout: 6)
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

    /// Скачиваем пару тяжёлых ресурсов YouTube и считаем скорость в Мбит/с.
    private static func measureSpeed() async -> Double {
        let session = session(timeout: 8)
        defer { session.invalidateAndCancel() }
        var bytes = 0
        let start = Date()
        for address in speedURLs {
            guard let url = URL(string: address),
                  let (data, _) = try? await session.data(from: url) else { continue }
            bytes += data.count
        }
        let seconds = Date().timeIntervalSince(start)
        guard bytes > 0, seconds > 0 else { return 0 }
        return Double(bytes) * 8 / seconds / 1_000_000
    }
}

// MARK: - Карточка режима на главном экране

struct StrategyCard: View {
    @EnvironmentObject var vpn: VPNManager
    @ObservedObject private var tuner = StrategyTuner.shared
    @State private var showCustom = false
    let palette: Palette

    private var kind: NetworkKind { NetworkWatcher.shared.kind }
    private var current: DPIStrategy { StrategyStore.load(kind) }

    private func apply(_ strategy: DPIStrategy) {
        StrategyStore.save(strategy, for: kind)
        if vpn.isOn { Task { _ = await vpn.restartAndWait() } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .foregroundColor(palette.light)

                Menu {
                    ForEach(DPIStrategy.allCases.filter { $0 != .custom }, id: \.self) { strategy in
                        Button(strategy.title) { apply(strategy) }
                    }
                    Divider()
                    Button("Своя стратегия…") { showCustom = true }
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
        .sheet(isPresented: $showCustom) {
            CustomStrategySheet { text in
                StrategyStore.customArgs = text
                apply(.custom)
            }
        }
    }
}

// MARK: - Своя стратегия (параметры ByeDPI строкой)

struct CustomStrategySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = StrategyStore.customArgs
    @State private var warning: String?
    let onSave: (String) -> Void

    private let examples = [
        "-d1 -r1+s",
        "-o1 -d1 -r1+s",
        "-q1+s -s3+s",
        "-s1+s -d3+s -r1+s",
        "-d1 -At,s -o1+s -At,s -q1+s"
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Своя стратегия")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.goldGradient)
                    Text("Параметры движка ByeDPI, как в командной строке: -s, -d, -o, -q, -r, -A. Приём -f (fake) на iPhone не работает.")
                        .font(Theme.body(13))
                        .foregroundColor(Theme.muted)

                    TextEditor(text: $text)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .scrollContentBackground(.hidden)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(height: 120)
                        .padding(10)
                        .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: Color.black.opacity(0.25))

                    if let warning {
                        Text(warning).font(Theme.body(12)).foregroundColor(Theme.crimson)
                    }

                    Text("ПРИМЕРЫ")
                        .font(Theme.label(11))
                        .tracking(3)
                        .foregroundColor(Theme.goldDim)
                    ForEach(examples, id: \.self) { example in
                        Button {
                            text = example
                        } label: {
                            Text(example)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .liquidGlass(RoundedRectangle(cornerRadius: 14, style: .continuous), tint: Color.black.opacity(0.2), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        let parts = clean.split(separator: " ")
                        if parts.contains(where: { $0.hasPrefix("-f") || $0 == "--fake" }) {
                            warning = "Приём -f (fake) на iPhone не работает, убери его."
                            return
                        }
                        onSave(clean)
                        dismiss()
                    } label: {
                        Text("Сохранить и включить")
                            .font(Theme.title(16))
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.35), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
