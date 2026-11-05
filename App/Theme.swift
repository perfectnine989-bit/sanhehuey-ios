import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x08090B)
    static let surface = Color(hex: 0x0F1714)
    static let card = Color(hex: 0x0D1210)
    static let gold = Color(hex: 0xC9A15A)
    static let goldLight = Color(hex: 0xE8CE94)
    static let goldDim = Color(hex: 0x9C8455)
    static let jade = Color(hex: 0x3FD9A0)
    static let crimson = Color(hex: 0xBC002D)
    static let text = Color(hex: 0xEDE4D4)
    static let muted = Color(hex: 0x7A7368)

    static func title(_ size: CGFloat) -> Font { .custom("RussoOne-Regular", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Oswald-Regular", size: size) }
    static func accent(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-Regular", size: size) }
}
