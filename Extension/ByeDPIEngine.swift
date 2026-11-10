import Darwin
import Foundation

/// Встроенный движок обхода DPI ByeDPI (MIT, github.com/hufrea/byedpi).
/// Работает как SOCKS5-прокси на 127.0.0.1 внутри расширения; sing-box отправляет в него
/// трафик, который нужно обходить. Запускается один раз на процесс расширения.
enum ByeDPIEngine {
    private static var started = false
    static var isRunning: Bool { started }

    /// Запускает движок в отдельном потоке и ждёт, пока порт начнёт принимать соединения.
    static func start(port: Int, strategyArgs: String) {
        guard !started else { return }
        started = true

        let strategy = strategyArgs.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
        // Базовые параметры: слушаем только локально, исходящие по IPv4, ограничиваем память
        // (не больше 200 соединений, буфер 8 КБ), таймаут TLS 3 с нужен для авто-цепочки.
        let args = ["byedpi", "-i", "127.0.0.1", "-p", String(port), "-I", "0.0.0.0",
                    "-c", "200", "-b", "8192", "-W", "3"] + strategy
        NSLog("[Sanhehuey] ByeDPI args: %@", args.joined(separator: " "))

        let thread = Thread {
            var cargs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
            cargs.append(nil)
            let code = byedpi_main(Int32(args.count), &cargs)
            NSLog("[Sanhehuey] ByeDPI stopped with code %d", code)
        }
        thread.stackSize = 1 << 20
        thread.name = "byedpi"
        thread.start()

        waitForPort(port, timeout: 1.5)
    }

    /// Ждём, пока движок откроет порт (чтобы первые соединения не упали).
    private static func waitForPort(_ port: Int, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            if fd >= 0 {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(UInt16(port).bigEndian)
                addr.sin_addr.s_addr = inet_addr("127.0.0.1")
                let result = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                close(fd)
                if result == 0 { return }
            }
            usleep(50_000)
        }
        NSLog("[Sanhehuey] ByeDPI port not ready after %.1fs", timeout)
    }
}
