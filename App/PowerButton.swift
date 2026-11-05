import SwiftUI
import UIKit

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct RippleWaves: View {
    let color: Color
    let active: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = fract(t / 3.6 + Double(i) / 3.0)
                    Circle()
                        .stroke(color.opacity((1 - p) * 0.5), lineWidth: 2)
                        .frame(width: 250, height: 250)
                        .scaleEffect(0.85 + CGFloat(p) * 0.5)
                }
            }
            .opacity(active ? 1 : 0)
            .animation(.easeInOut(duration: 0.6), value: active)
        }
        .allowsHitTesting(false)
    }
}

/// Кольцо из золотой драконьей чешуи с камнями по сторонам света.
struct ScaleRing: View {
    let palette: Palette

    var body: some View {
        ZStack {
            // тело кольца
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(hex: 0x6B4E22), Color(hex: 0xC9A15A), Color(hex: 0x3A2A10),
                            Color(hex: 0xA9832F), Color(hex: 0x5A4119), Color(hex: 0xC9A15A), Color(hex: 0x6B4E22)
                        ],
                        center: .center
                    ),
                    lineWidth: 28
                )
                .frame(width: 288, height: 288)

            // два ряда чешуи
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let count = 54
                for row in 0..<2 {
                    let r: CGFloat = row == 0 ? 134 : 126
                    let offset: Double = row == 0 ? 0.0 : 0.5
                    for i in 0..<count {
                        let a = (Double(i) + offset) / Double(count) * 2.0 * Double.pi
                        let center = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                        let rad: CGFloat = 9.5
                        let rect = CGRect(x: center.x - rad, y: center.y - rad, width: rad * 2, height: rad * 2)
                        let path = Path(ellipseIn: rect)
                        ctx.fill(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [Color(hex: 0xF6E2AE), Color(hex: 0xB8903F), Color(hex: 0x5E4320)]),
                                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                            )
                        )
                        ctx.stroke(path, with: .color(Color(hex: 0x2A1D0A).opacity(0.85)), lineWidth: 0.9)
                    }
                }
            }
            .frame(width: 288, height: 288)

            // тонкие золотые кромки
            Circle()
                .stroke(
                    LinearGradient(colors: [Color(hex: 0xFFF3D6), Theme.gold, Color(hex: 0x6B4E22)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 3
                )
                .frame(width: 294, height: 294)
            Circle()
                .stroke(
                    LinearGradient(colors: [Color(hex: 0x2A1D0A), Theme.goldDim], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 3
                )
                .frame(width: 232, height: 232)

            // камни
            ForEach(0..<4, id: \.self) { i in
                let a = Double(i) * Double.pi / 2.0
                gem
                    .offset(x: CGFloat(cos(a)) * 130, y: CGFloat(sin(a)) * 130)
            }
        }
    }

    private var gem: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, palette.light, palette.main],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 9
                )
            )
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Color(hex: 0x2A1D0A), lineWidth: 1.2))
            .shadow(color: palette.glow, radius: 6)
    }
}

struct PowerButton: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette
    @State private var spin = false

    private var hasRing: Bool { UIImage(named: "ring_dragon") != nil }

    private var label: String {
        switch vpn.status {
        case .connected: return "ОТКЛЮЧИТЬ"
        case .connecting, .reasserting: return "ПОДКЛЮЧЕНИЕ"
        case .disconnecting: return "ОТКЛЮЧЕНИЕ"
        default: return "ПОДКЛЮЧИТЬ"
        }
    }

    var body: some View {
        Button(action: { vpn.toggle() }) {
            ZStack {
                RippleWaves(color: palette.glow, active: vpn.isOn)

                ScaleRing(palette: palette)
                    .shadow(color: palette.glow.opacity(0.5), radius: 18)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 90).repeatForever(autoreverses: false), value: spin)

                // блик, бегущий по кольцу
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [Color.clear, Color.clear, Color.white.opacity(0.7), Color.clear, Color.clear],
                            center: .center
                        ),
                        lineWidth: 28
                    )
                    .frame(width: 288, height: 288)
                    .blendMode(.overlay)
                    .rotationEffect(.degrees(spin ? -360 : 0))
                    .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: spin)
                    .allowsHitTesting(false)

                if hasRing {
                    Image("ring_dragon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                }
                neonRing
                core
            }
            .frame(width: 320, height: 320)
        }
        .buttonStyle(PressScaleStyle())
        .onAppear { spin = true }
    }

    private var neonRing: some View {
        Circle()
            .stroke(palette.main, lineWidth: 2.5)
            .frame(width: 224, height: 224)
            .shadow(color: palette.glow, radius: 10)
            .shadow(color: palette.glow.opacity(0.6), radius: 22)
    }

    private var core: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.main.opacity(0.95), palette.main.opacity(0.4), Color.clear],
                        center: .center, startRadius: 4, endRadius: 108
                    )
                )
                .frame(width: 216, height: 216)
                .blur(radius: 6)

            VStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, palette.light], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: palette.glow, radius: 10)
                    .symbolEffect(.pulse, isActive: vpn.status == .connecting)
                Text(label)
                    .font(Theme.label(18))
                    .tracking(3)
                    .foregroundColor(Theme.text)
            }
            .frame(width: 206, height: 206)
            .liquidGlass(Circle(), tint: palette.main.opacity(0.28), interactive: true)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.clear, Color.white.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 206, height: 206)
            )
        }
    }
}
