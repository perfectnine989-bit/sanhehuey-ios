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

struct TickRing: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 2
            for i in 0..<96 {
                let a = Double(i) / 96.0 * 2.0 * Double.pi
                let ca = CGFloat(cos(a))
                let sa = CGFloat(sin(a))
                let long = i % 8 == 0
                let len: CGFloat = long ? 9 : 4
                var path = Path()
                path.move(to: CGPoint(x: c.x + ca * r, y: c.y + sa * r))
                path.addLine(to: CGPoint(x: c.x + ca * (r - len), y: c.y + sa * (r - len)))
                ctx.stroke(path, with: .color(Theme.goldDim.opacity(long ? 0.9 : 0.45)), lineWidth: long ? 1.6 : 1)
            }
        }
        .allowsHitTesting(false)
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
                outerRing
                TickRing()
                    .frame(width: 304, height: 304)
                    .rotationEffect(.degrees(spin ? -360 : 0))
                    .animation(.linear(duration: 120).repeatForever(autoreverses: false), value: spin)
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

    private var outerRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Theme.goldDim, Theme.goldLight, Color(hex: 0xFFF3D6), Theme.gold,
                        Color(hex: 0x4A3A1C), Theme.goldLight, Theme.goldDim
                    ],
                    center: .center
                ),
                lineWidth: 12
            )
            .frame(width: 274, height: 274)
            .shadow(color: palette.glow.opacity(0.55), radius: 16)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 45).repeatForever(autoreverses: false), value: spin)
    }

    private var neonRing: some View {
        Circle()
            .stroke(palette.main, lineWidth: 2.5)
            .frame(width: 234, height: 234)
            .shadow(color: palette.glow, radius: 10)
            .shadow(color: palette.glow.opacity(0.6), radius: 22)
    }

    private var core: some View {
        ZStack {
            // Цветной свет под стеклом, чтобы стекло было что преломлять
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.main.opacity(0.95), palette.main.opacity(0.4), Color.clear],
                        center: .center, startRadius: 4, endRadius: 112
                    )
                )
                .frame(width: 224, height: 224)
                .blur(radius: 6)

            VStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, palette.light], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: palette.glow, radius: 10)
                    .symbolEffect(.pulse, isActive: vpn.status == .connecting)
                Text(label)
                    .font(Theme.accent(15))
                    .tracking(3)
                    .foregroundColor(Theme.text)
            }
            .frame(width: 214, height: 214)
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
                    .frame(width: 214, height: 214)
            )
        }
    }
}
