import Foundation

/// Собирает конфиг sing-box (формат 1.12) под выбранный режим.
enum SingConfig {
    /// Домены, которые всегда идут напрямую в умном режиме.
    static let directSuffixes: [String] = [
        "ru", "su", "xn--p1ai", "xn--80asehdb", "xn--80aswg",
        "yandex.net", "yandex.com", "yastatic.net", "ya.ru", "yandexcloud.net",
        "vk.com", "vk.me", "vkuser.net", "vkuseraudio.net", "userapi.com", "vk-cdn.net",
        "mycdn.me", "okcdn.ru", "mail.ru", "imgsmail.ru",
        "sberbank.com", "tbank.ru", "tinkoff.ru", "gosuslugi.ru", "mos.ru",
        "2gis.com", "2gis.ru", "kinopoisk.ru", "avito.ru", "ozon.ru", "wildberries.ru",
        "wb.ru", "rutube.ru", "dzen.ru", "sber.ru", "alfabank.ru", "vtb.ru"
    ]

    // MARK: - Режим «Без сервера»

    /// Сайты, которые чаще всего режут по имени (DPI). Для точечных стратегий фрагментация только для них.
    static let blockedSuffixes: [String] = [
        "youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "ggpht.com", "youtube-nocookie.com",
        "youtubei.googleapis.com", "youtubekids.com", "yt.be", "gvt1.com",
        "instagram.com", "cdninstagram.com", "facebook.com", "fbcdn.net", "fb.com", "messenger.com",
        "whatsapp.com", "whatsapp.net", "x.com", "twitter.com", "twimg.com", "t.co",
        "discord.com", "discord.gg", "discordapp.com", "discordapp.net", "discord.media",
        "linkedin.com", "licdn.com", "rutracker.org", "rutracker.cc", "medium.com", "patreon.com",
        "signal.org", "proton.me", "protonmail.com", "soundcloud.com", "sndcdn.com", "viber.com"
    ]

    /// Порт встроенного движка ByeDPI (слушает только 127.0.0.1 внутри расширения).
    static let enginePort = 10801

    /// Конфиг без единого соединения с сервером: всё напрямую, обход DPI на телефоне.
    static func buildDirect(strategy: DPIStrategy, customArgs: String) -> String {
        let useEngine = strategy.engineArgs(custom: customArgs) != nil

        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
            // QUIC режем, чтобы приложения ушли на TCP, где работает обход
            ["network": "udp", "port": 443, "action": "reject"],
            ["ip_is_private": true, "action": "route", "outbound": "direct"],
            // Россия — обычное прямое соединение, без обхода
            ["domain_suffix": directSuffixes, "action": "route", "outbound": "direct"]
        ]
        var ruleSets: [[String: Any]] = []

        // Как отправлять то, что нужно обходить
        func bypassRule(_ match: [String: Any]) -> [String: Any] {
            var rule = match
            rule["action"] = "route"
            if useEngine {
                rule["outbound"] = "desync"
            } else {
                rule["outbound"] = "direct"
                for (key, value) in strategy.fragment ?? [:] { rule[key] = value }
            }
            return rule
        }

        // 1) Известные заблокированные — всегда через обход, даже если сервер внутри России (кэши Google)
        routeRules.append(bypassRule(["domain_suffix": blockedSuffixes]))

        // 2) Остальные российские адреса — напрямую
        if let path = Bundle.main.path(forResource: "geoip-ru", ofType: "srs") {
            ruleSets.append(["type": "local", "tag": "geoip-ru", "format": "binary", "path": path])
            routeRules.append(["rule_set": ["geoip-ru"], "action": "route", "outbound": "direct"])
        }

        // 3) Весь прочий веб (HTTPS и HTTP) — тоже через обход
        routeRules.append(bypassRule(["network": "tcp", "port": [443, 80]]))

        var route: [String: Any] = [
            "rules": routeRules,
            "final": "direct",
            "auto_detect_interface": true,
            "default_domain_resolver": "dns-doh"
        ]
        if !ruleSets.isEmpty { route["rule_set"] = ruleSets }

        let doh: [String: Any] = [
            "type": "https",
            "tag": "dns-doh",
            "server": "77.88.8.8",
            "path": "/dns-query",
            "tls": ["enabled": true, "server_name": "common.dot.dns.yandex.net"]
        ]
        let tun: [String: Any] = [
            "type": "tun",
            "tag": "tun-in",
            "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
            "mtu": 1400,
            "auto_route": true,
            "stack": "mixed"
        ]
        var outbounds: [[String: Any]] = [["type": "direct", "tag": "direct"]]
        if useEngine {
            outbounds.append([
                "type": "socks",
                "tag": "desync",
                "server": "127.0.0.1",
                "server_port": enginePort,
                "version": "5"
            ])
        }
        let dns: [String: Any] = ["servers": [doh], "final": "dns-doh", "strategy": "ipv4_only"]

        let config: [String: Any] = [
            "log": ["level": "warn", "timestamp": true],
            "dns": dns,
            "inbounds": [tun],
            "outbounds": outbounds,
            "route": route
        ]
        let data = (try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// UDP-порты сервера в порядке предпочтения. На сервере 4500, 3478 и 500 перенаправлены на Hysteria2.
    /// Операторы их почти не трогают (IPsec NAT-T, STUN, IKE), в отличие от 443, который режут и тормозят.
    static let udpPorts = [4500, 3478, 500]

    /// `server` — уже готовый IPv4-адрес сервера (см. ServerResolver), чтобы запуск не зависел от DNS.
    static func build(mode: RouteMode, server: String) -> String {
        // Несколько входов на один сервер. Пока проверка не завершена, идёт первый (4500),
        // потом группа сама держится того порта, который отвечает быстрее всех.
        func hysteria(tag: String, port: Int) -> [String: Any] {
            return [
                "type": "hysteria2",
                "tag": tag,
                "server": server,
                "server_port": port,
                "password": Credentials.password,
                "obfs": [
                    "type": "salamander",
                    "password": Credentials.obfsPassword
                ],
                "tls": [
                    "enabled": true,
                    "server_name": Credentials.sni
                ]
            ]
        }
        var ports = udpPorts
        if !ports.contains(Credentials.port) { ports.append(Credentials.port) }
        let tags: [String] = ports.map { "hy2-\($0)" }
        let endpoints: [[String: Any]] = ports.map { hysteria(tag: "hy2-\($0)", port: $0) }
        let proxy: [String: Any] = [
            "type": "urltest",
            "tag": "proxy",
            "outbounds": tags,
            "url": "https://www.gstatic.com/generate_204",
            "interval": "30s",
            "tolerance": 100,
            "idle_timeout": "30m",
            "interrupt_exist_connections": false
        ]

        var dnsRules: [[String: Any]] = []
        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
            // QUIC (UDP 443) внутри туннеля отклоняем: приложения мгновенно переходят на TCP.
            // QUIC поверх QUIC даёт зависания видео (Shorts) из-за двойного контроля перегрузки.
            ["network": "udp", "port": 443, "action": "reject"],
            ["ip_is_private": true, "action": "route", "outbound": "direct"]
        ]
        var ruleSets: [[String: Any]] = []

        if mode == .smart {
            dnsRules.append(["domain_suffix": directSuffixes, "action": "route", "server": "dns-local"])
            routeRules.append(["domain_suffix": directSuffixes, "action": "route", "outbound": "direct"])
            if let path = Bundle.main.path(forResource: "geoip-ru", ofType: "srs") {
                ruleSets.append([
                    "type": "local",
                    "tag": "geoip-ru",
                    "format": "binary",
                    "path": path
                ])
                routeRules.append(["rule_set": ["geoip-ru"], "action": "route", "outbound": "direct"])
            }
        }

        var route: [String: Any] = [
            "rules": routeRules,
            "final": "proxy",
            "auto_detect_interface": true,
            "default_domain_resolver": "dns-local"
        ]
        if !ruleSets.isEmpty { route["rule_set"] = ruleSets }

        let direct: [String: Any] = ["type": "direct", "tag": "direct"]
        let outbounds: [[String: Any]] = [proxy] + endpoints + [direct]

        let config: [String: Any] = [
            "log": ["level": "warn", "timestamp": true],
            "dns": [
                "servers": [
                    ["type": "udp", "tag": "dns-local", "server": "77.88.8.8"],
                    ["type": "https", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"]
                ],
                "rules": dnsRules,
                "final": "dns-remote",
                "strategy": "ipv4_only"
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                "mtu": 1400,
                "auto_route": true,
                "stack": "mixed"
            ]],
            "outbounds": outbounds,
            "route": route
        ]

        let data = (try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
