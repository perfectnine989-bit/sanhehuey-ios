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

    static func build(mode: RouteMode) -> String {
        let proxy: [String: Any] = [
            "type": "hysteria2",
            "tag": "proxy",
            "server": Credentials.server,
            "server_port": Credentials.port,
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

        var dnsRules: [[String: Any]] = []
        var routeRules: [[String: Any]] = [
            ["action": "sniff"],
            ["protocol": "dns", "action": "hijack-dns"],
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

        let config: [String: Any] = [
            "log": ["level": "warn", "timestamp": true],
            "dns": [
                "servers": [
                    ["type": "udp", "tag": "dns-local", "server": "77.88.8.8"],
                    ["type": "https", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"]
                ],
                "rules": dnsRules,
                "final": "dns-remote"
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                "mtu": 1400,
                "auto_route": true,
                "stack": "mixed"
            ]],
            "outbounds": [
                proxy,
                ["type": "direct", "tag": "direct"]
            ],
            "route": route
        ]

        let data = (try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
