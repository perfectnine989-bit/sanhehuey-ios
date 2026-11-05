import Combine
import Foundation
import NetworkExtension
import UIKit

@MainActor
final class VPNManager: ObservableObject {
    @Published var status: NEVPNStatus = .disconnected
    @Published var connectedDate: Date?
    @Published var errorText: String?
    @Published var mode: RouteMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "routeMode") }
    }

    let traffic = TrafficMonitor()

    private var manager: NETunnelProviderManager?
    private var cancellable: AnyCancellable?
    private var sessionStart: Date?

    init() {
        let saved = UserDefaults.standard.string(forKey: "routeMode") ?? ""
        mode = RouteMode(rawValue: saved) ?? .smart

        cancellable = NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self, let conn = note.object as? NEVPNConnection else { return }
                self.apply(conn.status, conn.connectedDate, silent: false)
            }

        Task { await refresh() }
    }

    var isOn: Bool { status == .connected || status == .connecting || status == .reasserting }

    var statusText: String {
        switch status {
        case .connected: return "Защищено"
        case .connecting, .reasserting: return "Подключение…"
        case .disconnecting: return "Отключение…"
        default: return "Не подключено"
        }
    }

    private func apply(_ newStatus: NEVPNStatus, _ date: Date?, silent: Bool) {
        let previous = status
        status = newStatus
        connectedDate = date

        if newStatus == .connected, previous != .connected {
            sessionStart = date ?? Date()
            StatsStore.shared.markActiveToday()
            traffic.start()
            if !silent {
                Haptics.connected()
            }
        }
        if newStatus != .connected, previous == .connected {
            if let start = sessionStart {
                StatsStore.shared.finishSession(seconds: Date().timeIntervalSince(start))
            }
            sessionStart = nil
            traffic.stop()
            Haptics.disconnected()
        }
    }

    /// Находим bundle id расширения прямо внутри приложения (на случай, если подпись переименует ID).
    private func extensionBundleID() -> String {
        if let url = Bundle.main.builtInPlugInsURL,
           let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
           let appex = items.first(where: { $0.pathExtension == "appex" }),
           let id = Bundle(url: appex)?.bundleIdentifier {
            return id
        }
        return (Bundle.main.bundleIdentifier ?? "") + ".tunnel"
    }

    private func refresh() async {
        do {
            let all = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = all.first
            if let conn = manager?.connection {
                apply(conn.status, conn.connectedDate, silent: true)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func prepare() async throws -> NETunnelProviderManager {
        let m = manager ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = extensionBundleID()
        proto.serverAddress = "SanHeHuey"
        proto.providerConfiguration = ["mode": mode.rawValue]
        m.protocolConfiguration = proto
        m.localizedDescription = "SanHeHuey"
        m.isEnabled = true
        try await m.saveToPreferences()
        try await m.loadFromPreferences()
        manager = m
        return m
    }

    func toggle() {
        Haptics.press()
        errorText = nil
        if isOn {
            manager?.connection.stopVPNTunnel()
        } else {
            Task {
                do {
                    let m = try await prepare()
                    try m.connection.startVPNTunnel()
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    func setMode(_ newMode: RouteMode) {
        guard newMode != mode else { return }
        mode = newMode
        if isOn {
            // Перезапускаем туннель, чтобы применились новые правила.
            manager?.connection.stopVPNTunnel()
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                do {
                    let m = try await prepare()
                    try m.connection.startVPNTunnel()
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }
}
