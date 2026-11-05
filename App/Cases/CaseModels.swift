import SwiftUI

enum Rarity: String, CaseIterable {
    case common, uncommon, rare, epic, legendary

    var color: Color {
        switch self {
        case .common: return Color(hex: 0x8A93A3)
        case .uncommon: return Color(hex: 0x2FD7A2)
        case .rare: return Color(hex: 0x3B82F6)
        case .epic: return Color(hex: 0xA855F7)
        case .legendary: return Color(hex: 0xE8C173)
        }
    }

    var label: String {
        switch self {
        case .common: return "Обычный"
        case .uncommon: return "Необычный"
        case .rare: return "Редкий"
        case .epic: return "Эпический"
        case .legendary: return "Легендарный"
        }
    }

    /// Названия из сайта: Трофей, Добыча, Ценность, Реликвия, Джекпот.
    var title: String {
        switch self {
        case .common: return "Трофей"
        case .uncommon: return "Добыча"
        case .rare: return "Ценность"
        case .epic: return "Реликвия"
        case .legendary: return "Джекпот"
        }
    }

    var sortRank: Int {
        switch self {
        case .legendary: return 0
        case .epic: return 1
        case .rare: return 2
        case .uncommon: return 3
        case .common: return 4
        }
    }

    static func parse(_ s: String?) -> Rarity { Rarity(rawValue: (s ?? "").lowercased()) ?? .common }
}

struct ManualReward {
    var kind: String
    var months: Int
    var prizeName: String
    var service: String
    var username: String
    var claimToken: String

    init(_ d: [String: Any]) {
        kind = jStr(d["kind"])
        months = jInt(d["months"])
        prizeName = jStr(d["prize_name"])
        service = jStr(d["service"])
        username = jStr(d["username"])
        claimToken = jStr(d["claim_token"])
    }
}

struct Prize: Identifiable {
    let id = UUID()
    var name: String
    var rarity: Rarity
    var days: Int
    var chance: Double
    var manual: ManualReward?

    init(name: String, rarity: Rarity, days: Int, chance: Double) {
        self.name = name
        self.rarity = rarity
        self.days = days
        self.chance = chance
        self.manual = nil
    }

    init(json d: [String: Any]) {
        let n = jStr(d["name"])
        name = n.isEmpty ? (jStr(d["prize"]).isEmpty ? "Приз" : jStr(d["prize"])) : n
        rarity = Rarity.parse(jStr(d["rarity"]))
        days = jInt(d["days"])
        chance = jNum(d["chance"] ?? d["display_chance"])
        if let m = d["manual_reward"] as? [String: Any] { manual = ManualReward(m) } else { manual = nil }
    }

    var chanceText: String {
        let text = chance == chance.rounded() ? String(Int(chance)) : String(chance)
        return text.replacingOccurrences(of: ".", with: ",") + "%"
    }
}

struct CaseDef: Identifiable {
    let id: String
    var name: String
    var price: Double
    var prizes: [Prize]

    init(id: String, name: String, price: Double, prizes: [Prize]) {
        self.id = id
        self.name = name
        self.price = price
        self.prizes = prizes
    }

    init(id: String, json d: [String: Any]) {
        self.id = id
        let n = jStr(d["name"])
        name = n.isEmpty ? CaseThemes.defaultName(id) : n
        price = jNum(d["price"])
        prizes = (d["prizes"] as? [[String: Any]] ?? []).map { Prize(json: $0) }
    }

    static let free = CaseDef(id: "free", name: "Дань семьи", price: 0, prizes: [
        Prize(name: "3 дня VPN", rarity: .common, days: 3, chance: 62),
        Prize(name: "5 дней VPN", rarity: .uncommon, days: 5, chance: 27),
        Prize(name: "7 дней VPN", rarity: .rare, days: 7, chance: 10.8),
        Prize(name: "100₽ на баланс", rarity: .epic, days: 0, chance: 0.2)
    ])
}

struct CaseTheme {
    let accent: Color
    let deep: Color
    let surface: Color
    let poster: String
    let subtitle: String
    let mainPrize: String
}

enum CaseThemes {
    static let order = ["free", "red60", "g", "safe200", "topg", "contract800"]

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }

    static func defaultName(_ id: String) -> String {
        switch id {
        case "free": return "Дань семьи"
        case "red60": return "Красный конверт"
        case "g": return "Кейс G"
        case "safe200": return "Сейф семьи"
        case "topg": return "Кейс Top G"
        case "contract800": return "Чёрный контракт"
        default: return "Кейс"
        }
    }

    static func theme(_ id: String) -> CaseTheme {
        switch id {
        case "free":
            return CaseTheme(accent: rgb(78, 190, 145), deep: rgb(18, 68, 49), surface: rgb(8, 20, 17), poster: "poster_family",
                             subtitle: "Семья помнит тех, кто возвращается.", mainPrize: "100₽ на баланс")
        case "red60":
            return CaseTheme(accent: rgb(183, 147, 97), deep: rgb(82, 58, 31), surface: rgb(16, 14, 16), poster: "poster_red60",
                             subtitle: "Запечатанное послание. Внутри может быть больше, чем кажется.", mainPrize: "1 месяц VPN")
        case "safe200":
            return CaseTheme(accent: rgb(168, 102, 226), deep: rgb(57, 26, 82), surface: rgb(19, 10, 28), poster: "poster_safe200",
                             subtitle: "Содержимое сейфа видят только свои.", mainPrize: "Telegram Premium 1 месяц")
        case "topg":
            return CaseTheme(accent: rgb(226, 181, 91), deep: rgb(84, 55, 17), surface: rgb(24, 18, 8), poster: "poster_topg",
                             subtitle: "Высшая ставка. Награды соответствуют риску.", mainPrize: "Telegram Premium 1 год")
        case "contract800":
            return CaseTheme(accent: rgb(170, 174, 186), deep: rgb(76, 80, 92), surface: rgb(11, 11, 13), poster: "poster_contract800",
                             subtitle: "Подпись поставлена. Назад дороги нет.", mainPrize: "БЕЗЛИМИТ")
        default:
            return CaseTheme(accent: rgb(208, 50, 46), deep: rgb(92, 18, 18), surface: rgb(28, 8, 10), poster: "poster_g",
                             subtitle: "Красная зона. Здесь решает только удача.", mainPrize: "Telegram Premium 1 месяц")
        }
    }
}

/// Картинки призов: как на сайте (prizeMafiaFileV2), с запасным эмодзи.
enum PrizeArt {
    static func file(name: String, days: Int) -> String? {
        let v = name.lowercased()
        if days == -1 || v.contains("второй шанс") { return "second-chance" }
        if v.contains("музык") { return "music-prize-v16" }
        if v.contains("premium") || v.contains("премиум") {
            return (v.contains("год") || v.contains("12")) ? "telegram-premium-1y" : "telegram-premium-1m"
        }
        if v.contains("безлимит") { return "unlimited" }
        if v.contains("₽") || v.contains("баланс") { return "balance-100" }
        if v.contains("vpn") {
            if v.contains("14") { return "vpn-14d" }
            if v.contains("7") { return "vpn-7d" }
            if v.contains("5") { return "vpn-5d" }
            if v.contains("6 месяц") { return "vpn-6m" }
            if v.contains("3 месяц") { return "vpn-3m" }
            if v.contains("1 год") || v.contains("12 месяц") || v.contains("365") { return "vpn-1y" }
            if v.contains("1 месяц") || v.contains("30 д") { return "vpn-1m" }
            if v.contains("3 дня") || v.contains("3 день") || v.contains("3 дней") { return "vpn-3d" }
        }
        return nil
    }

    static func emoji(_ name: String) -> String {
        let map: [String: String] = [
            "3 дня VPN": "🃏", "7 дней VPN": "💣", "14 дней VPN": "🐉", "1 месяц VPN": "🔫", "3 месяца VPN": "💀",
            "6 месяцев VPN": "🗡️", "1 год VPN": "👑", "Telegram Premium 1 мес": "⭐", "Telegram Premium 1 год": "💎",
            "БЕЗЛИМИТ": "♾️", "5 дней VPN": "💫", "100₽ на баланс": "💰", "Второй шанс": "🔄"
        ]
        return map[name] ?? "🎁"
    }
}

struct PrizeImage: View {
    let name: String
    let days: Int
    var size: CGFloat = 80

    var body: some View {
        if let file = PrizeArt.file(name: name, days: days), UIImage(named: "prize_" + file) != nil {
            Image("prize_" + file)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(PrizeArt.emoji(name))
                .font(.system(size: size * 0.62))
                .frame(width: size, height: size)
        }
    }
}
