// Заглушка. При сборке в GitHub Actions файл перезаписывается ключом из секрета HY2_LINK.
enum Credentials {
    static let server = ""
    static let port = 443
    static let password = ""
    static let sni = ""
    static let obfsPassword = ""
    // VLESS Reality (секрет VLESS_LINK). Пустой uuid — Reality не настроен.
    static let realityServer = ""
    static let realityPort = 8443
    static let realityUUID = ""
    static let realityPublicKey = ""
    static let realityShortID = ""
    static let realitySNI = ""
}
