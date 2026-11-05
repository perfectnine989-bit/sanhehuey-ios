import NetworkExtension
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

func fract(_ v: Double) -> Double { v - floor(v) }

/// Цветовая схема меняется от состояния: красная (выкл), янтарная (подключение), изумрудная (включено).
struct Palette {
    let main: Color
    let light: Color
    let glow: Color

    static let idle = Palette(main: Color(hex: 0xD81E3C), light: Color(hex: 0xFF8A78), glow: Color(hex: 0xFF2D4F))
    static let busy = Palette(main: Color(hex: 0xF2A21E), light: Color(hex: 0xFFD684), glow: Color(hex: 0xFFB020))
    static let on = Palette(main: Color(hex: 0x24C58E), light: Color(hex: 0xC4FFE8), glow: Color(hex: 0x3FD9A0))

    static func forStatus(_ status: NEVPNStatus) -> Palette {
        switch status {
        case .connected: return .on
        case .connecting, .reasserting, .disconnecting: return .busy
        default: return .idle
        }
    }
}

enum Theme {
    static let bg = Color(hex: 0x050506)
    static let surface = Color(hex: 0x0F1714)
    static let card = Color(hex: 0x0D1210)
    static let gold = Color(hex: 0xC9A15A)
    static let goldLight = Color(hex: 0xE8CE94)
    static let goldDim = Color(hex: 0x9C8455)
    static let jade = Color(hex: 0x3FD9A0)
    static let crimson = Color(hex: 0xBC002D)
    static let text = Color(hex: 0xEDE4D4)
    static let muted = Color(hex: 0x8A8276)

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFFF1CF), Color(hex: 0xE8CE94), Color(hex: 0xC9A15A)],
        startPoint: .top, endPoint: .bottom
    )

    static func title(_ size: CGFloat) -> Font { .custom("RussoOne-Regular", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Oswald-Regular", size: size) }
    static func accent(_ size: CGFloat) -> Font { .custom("PlayfairDisplay-Regular", size: size) }
}
