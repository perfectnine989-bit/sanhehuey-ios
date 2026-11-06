import Foundation

/// Определяет IPv4-адрес сервера обычным системным DNS (оператора) до запуска туннеля.
/// Так подключение не зависит от публичных DNS, которые на мобильных сетях и точках доступа могут тормозить.
/// Последний удачный адрес запоминается на случай, если DNS недоступен.
enum ServerResolver {
    private static let cacheKey = "server.ip.v4"

    private final class Box {
        var value: String?
    }

    static func resolve(_ host: String) -> String {
        if isIPv4(host) { return host }

        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.value = lookup(host)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 4)

        if let ip = box.value {
            UserDefaults.standard.set(ip, forKey: cacheKey)
            return ip
        }
        return UserDefaults.standard.string(forKey: cacheKey) ?? host
    }

    private static func isIPv4(_ s: String) -> Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, s, &addr) == 1
    }

    private static func lookup(_ host: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return nil }
        defer { freeaddrinfo(result) }

        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let node = cursor {
            if node.pointee.ai_family == AF_INET, let addr = node.pointee.ai_addr {
                var sin = sockaddr_in()
                memcpy(&sin, addr, MemoryLayout<sockaddr_in>.size)
                var inAddr = sin.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &inAddr, &buffer, socklen_t(INET_ADDRSTRLEN))
                return String(cString: buffer)
            }
            cursor = node.pointee.ai_next
        }
        return nil
    }
}
