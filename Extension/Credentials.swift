// Заглушка. При сборке в GitHub Actions файл перезаписывается ключом из секрета HY2_LINK.
enum Credentials {
    static let server = ""
    static let port = 443
    static let password = ""
    static let sni = ""
    static let obfsPassword = ""
}
