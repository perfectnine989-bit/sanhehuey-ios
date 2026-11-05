import Foundation
import UIKit

struct APIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func jNum(_ v: Any?) -> Double {
    if let n = v as? NSNumber { return n.doubleValue }
    if let s = v as? String, let d = Double(s.replacingOccurrences(of: ",", with: ".")) { return d }
    return 0
}

func jStr(_ v: Any?) -> String {
    if let s = v as? String { return s }
    if let n = v as? NSNumber { return n.stringValue }
    return ""
}

func jBool(_ v: Any?) -> Bool {
    if let b = v as? Bool { return b }
    if let n = v as? NSNumber { return n.boolValue }
    return false
}

func jInt(_ v: Any?) -> Int { Int(jNum(v)) }

/// Клиент твоего сайта. Сессия живёт в cookie, как в браузере; cookie сохраняем между запусками.
final class SiteAPI {
    static let shared = SiteAPI()
    let base = URL(string: "https://sanhehuey.online")!
    private let session: URLSession
    private let cookieKey = "site.cookies.v1"

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        restoreCookies()
    }

    // MARK: cookie

    func saveCookies() {
        let cookies = HTTPCookieStorage.shared.cookies(for: base) ?? []
        var list: [[String: Any]] = []
        for cookie in cookies {
            guard let props = cookie.properties else { continue }
            var dict: [String: Any] = [:]
            for (key, value) in props { dict[key.rawValue] = value }
            list.append(dict)
        }
        UserDefaults.standard.set(list, forKey: cookieKey)
    }

    private func restoreCookies() {
        guard let list = UserDefaults.standard.array(forKey: cookieKey) as? [[String: Any]] else { return }
        for dict in list {
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (key, value) in dict { props[HTTPCookiePropertyKey(rawValue: key)] = value }
            if let cookie = HTTPCookie(properties: props) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }

    func clearCookies() {
        for cookie in HTTPCookieStorage.shared.cookies(for: base) ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        UserDefaults.standard.removeObject(forKey: cookieKey)
    }

    // MARK: запросы

    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> (Int, Data) {
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else { throw APIError("Неверный адрес") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if method == "POST" {
            req.httpBody = Data()
        }
        let (data, response) = try await session.data(for: req)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    func json(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> (status: Int, obj: [String: Any]) {
        let (status, data) = try await request(path, method: method, body: body)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (status, obj)
    }

    /// Бросает ошибку с текстом сервера, если запрос не успешен.
    func jsonOK(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
        let result = try await json(path, method: method, body: body)
        if !(200..<300).contains(result.status) {
            let detail = result.obj["detail"]
            if let text = detail as? String, !text.isEmpty { throw APIError(text) }
            if let text = result.obj["message"] as? String, !text.isEmpty { throw APIError(text) }
            throw APIError("Ошибка \(result.status)")
        }
        return result.obj
    }
}
