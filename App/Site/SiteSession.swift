import SwiftUI
import UIKit

enum LoginState: Equatable {
    case idle
    case waiting
    case failed(String)
}

/// Аккаунт с сайта: вход через Telegram, баланс, аватарка и статус Telegram, уровень семьи.
@MainActor
final class SiteSession: ObservableObject {
    @Published var user: [String: Any] = [:]
    @Published var balance: Double = 0
    @Published var avatar: UIImage?
    @Published var login: LoginState = .idle
    @Published var loaded = false

    private var loginToken: String?
    private var pollTask: Task<Void, Never>?
    private let api = SiteAPI.shared

    var isLoggedIn: Bool { jBool(user["exists"]) }
    var telegramLinked: Bool { jBool(user["telegram_linked"]) || jStr(user["auth_source"]) == "telegram" }
    var tgUsername: String { jStr(user["tg_username"]).replacingOccurrences(of: "@", with: "") }

    var displayName: String {
        let name = jStr(user["client_name"])
        if !name.isEmpty { return name }
        if !tgUsername.isEmpty { return "@" + tgUsername }
        return "Гость"
    }

    var dailyCaseLast: Date? { Self.parseDate(jStr(user["daily_case_last"])) }

    static func parseDate(_ s: String) -> Date? {
        if s.isEmpty { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = format
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    // MARK: загрузка данных

    func refresh() async {
        if let r = try? await api.json("/api/me"), r.status == 200 {
            user = r.obj
            api.saveCookies()
        }
        loaded = true
        guard isLoggedIn else {
            balance = 0
            avatar = nil
            return
        }
        if let b = try? await api.json("/api/balance"), b.status == 200 {
            balance = jNum(b.obj["balance"])
        }
        if telegramLinked {
            await loadAvatar()
        } else {
            avatar = nil
        }
    }

    private func loadAvatar() async {
        if let (status, data) = try? await api.request("/api/telegram/avatar"), status == 200, let image = UIImage(data: data) {
            avatar = image
        }
    }

    // MARK: вход через Telegram

    func startTelegramLogin(link: Bool = false) async {
        pollTask?.cancel()
        login = .waiting
        do {
            let d = try await api.jsonOK(link ? "/api/auth/link-request" : "/api/auth/request")
            if jStr(d["status"]) == "already_linked" {
                login = .idle
                await refresh()
                return
            }
            let token = jStr(d["token"])
            guard !token.isEmpty else { throw APIError("Сервер не выдал токен входа") }
            loginToken = token
            let botURL = jStr(d["bot_url"])
            let primary = link ? botURL : "tg://resolve?domain=SanHaHuay_Bot&start=auth_\(token)"
            openTelegram(primary, fallback: botURL)
            poll(token)
        } catch {
            login = .failed(error.localizedDescription)
        }
    }

    private func openTelegram(_ primary: String, fallback: String) {
        guard let url = URL(string: primary) else { return }
        UIApplication.shared.open(url) { ok in
            if !ok, let fb = URL(string: fallback) {
                UIApplication.shared.open(fb)
            }
        }
    }

    private func poll(_ token: String) {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                guard let self else { return }
                if await self.checkToken(token) { return }
            }
            self?.login = .failed("Время ожидания вышло. Попробуй ещё раз.")
        }
    }

    @discardableResult
    func checkToken(_ token: String) async -> Bool {
        guard let r = try? await api.json("/api/auth/verify/\(token)") else { return false }
        switch jStr(r.obj["status"]) {
        case "ok", "linked":
            api.saveCookies()
            loginToken = nil
            login = .idle
            await refresh()
            return true
        case "expired", "invalid":
            loginToken = nil
            login = .failed("Ссылка входа устарела. Попробуй ещё раз.")
            return true
        default:
            return false
        }
    }

    /// Вызывается, когда приложение снова стало активным (после возврата из Telegram).
    func resumeLoginCheck() {
        guard let token = loginToken else { return }
        Task { _ = await checkToken(token) }
    }

    func cancelLogin() {
        pollTask?.cancel()
        loginToken = nil
        login = .idle
    }

    func logout() async {
        _ = try? await api.json("/api/auth/logout", method: "POST")
        api.clearCookies()
        user = [:]
        balance = 0
        avatar = nil
    }
}
