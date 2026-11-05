import Foundation
import UIKit

// MARK: - Статистика профиля (хранится на телефоне)

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var totalSeconds: Double
    @Published private(set) var sessions: Int
    @Published private(set) var totalBytes: Double
    @Published private(set) var activeDays: [String]
    let firstLaunch: Date

    init() {
        let defaults = UserDefaults.standard
        totalSeconds = defaults.double(forKey: "st.seconds")
        sessions = defaults.integer(forKey: "st.sessions")
        totalBytes = defaults.double(forKey: "st.bytes")
        activeDays = defaults.stringArray(forKey: "st.days") ?? []
        if let saved = defaults.object(forKey: "st.first") as? Date {
            firstLaunch = saved
        } else {
            let now = Date()
            defaults.set(now, forKey: "st.first")
            firstLaunch = now
        }
    }

    func addBytes(_ bytes: Double) {
        totalBytes += bytes
        UserDefaults.standard.set(totalBytes, forKey: "st.bytes")
    }

    func finishSession(seconds: Double) {
        totalSeconds += max(0, seconds)
        sessions += 1
        UserDefaults.standard.set(totalSeconds, forKey: "st.seconds")
        UserDefaults.standard.set(sessions, forKey: "st.sessions")
    }

    func markActiveToday() {
        let key = Self.dayKey(Date())
        if !activeDays.contains(key) {
            activeDays.append(key)
            UserDefaults.standard.set(activeDays, forKey: "st.days")
        }
    }

    /// Сколько дней подряд (включая сегодня) VPN был включён.
    var streak: Int {
        let set = Set(activeDays)
        let calendar = Calendar.current
        var day = Date()
        var count = 0
        while set.contains(Self.dayKey(day)), count < 3650 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Пинг через туннель

final class PingProbe: NSObject, URLSessionTaskDelegate {
    private var completion: ((Int?) -> Void)?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func measure(_ done: @escaping (Int?) -> Void) {
        completion = done
        var request = URLRequest(url: URL(string: "https://www.gstatic.com/generate_204")!)
        request.httpMethod = "HEAD"
        session.dataTask(with: request) { [weak self] _, _, error in
            if error != nil { self?.finish(nil) }
        }.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let m = metrics.transactionMetrics.last,
           let start = m.requestStartDate,
           let response = m.responseStartDate {
            finish(Int(response.timeIntervalSince(start) * 1000))
        } else {
            finish(nil)
        }
    }

    private func finish(_ ms: Int?) {
        let callback = completion
        completion = nil
        DispatchQueue.main.async { callback?(ms) }
    }
}

// MARK: - Реальная скорость: читаем счётчики туннельного интерфейса

@MainActor
final class TrafficMonitor: ObservableObject {
    @Published var down: Double = 0   // Мбит/с
    @Published var up: Double = 0     // Мбит/с
    @Published var pingMs: Int? = nil

    private var timer: Timer?
    private var last: (rx: UInt32, tx: UInt32, time: Date)?
    private var ticks = 0
    private let probe = PingProbe()

    func start() {
        stop()
        ticks = 0
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        sample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        last = nil
        down = 0
        up = 0
        pingMs = nil
    }

    private func sample() {
        let now = Date()
        if let c = Self.tunCounters() {
            if let prev = last {
                let dt = now.timeIntervalSince(prev.time)
                if dt > 0.2 {
                    let rx = Double(c.rx &- prev.rx)
                    let tx = Double(c.tx &- prev.tx)
                    down = rx * 8 / dt / 1_000_000
                    up = tx * 8 / dt / 1_000_000
                    StatsStore.shared.addBytes(rx + tx)
                }
            }
            last = (c.rx, c.tx, now)
        }
        if ticks % 5 == 0 {
            probe.measure { [weak self] ms in
                Task { @MainActor in self?.pingMs = ms }
            }
        }
        ticks += 1
    }

    /// Ищем интерфейс с адресом 172.19.0.1 (наш туннель) и читаем его счётчики байт.
    private static func tunCounters() -> (rx: UInt32, tx: UInt32)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var tunName: String?
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let node = cursor {
            defer { cursor = node.pointee.ifa_next }
            guard let addr = node.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var sin = sockaddr_in()
            memcpy(&sin, addr, MemoryLayout<sockaddr_in>.size)
            var inAddr = sin.sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &inAddr, &buffer, socklen_t(INET_ADDRSTRLEN))
            if String(cString: buffer) == "172.19.0.1" {
                tunName = String(cString: node.pointee.ifa_name)
            }
        }
        guard let name = tunName else { return nil }

        cursor = first
        while let node = cursor {
            defer { cursor = node.pointee.ifa_next }
            guard let addr = node.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  String(cString: node.pointee.ifa_name) == name,
                  let data = node.pointee.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            return (stats.ifi_ibytes, stats.ifi_obytes)
        }
        return nil
    }
}
