import SwiftUI
import UIKit

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
                        .stroke(color.opacity((1 - p) * 0.35), lineWidth: 1.5)
                        .frame(width: 266, height: 266)
                        .scaleEffect(1.0 + CGFloat(p) * 0.18)
                }
            }
            .opacity(active ? 1 : 0)
            .animation(.easeInOut(duration: 0.6), value: active)
        }
        .allowsHitTesting(false)
    }
}

/// Дуга, бегущая по кольцу.
struct SpinningArc: View {
    let period: Double
    let length: CGFloat
    let color: Color
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: length)
            .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            .shadow(color: color, radius: 6)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: period).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

struct PowerButton: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette

    private var connecting: Bool { vpn.status == .connecting || vpn.status == .reasserting }
    private var connected: Bool { vpn.status == .connected }

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
                RippleWaves(color: palette.glow, active: connected)
                ring
                core
            }
            .frame(width: 300, height: 300)
        }
        .buttonStyle(PressScaleStyle())
    }

    /// Минималистичное кольцо: тонкая золотая линия + светящаяся дуга.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.gold.opacity(0.25), lineWidth: 0.8)
                .frame(width: 290, height: 290)

            Circle()
                .stroke(
                    connected
                        ? AnyShapeStyle(palette.glow)
                        : AnyShapeStyle(
                            AngularGradient(
                                colors: [
                                    Theme.gold.opacity(0.22), Theme.goldLight, Theme.gold.opacity(0.22),
                                    Theme.gold.opacity(0.6), Theme.gold.opacity(0.22)
                                ],
                                center: .center
                            )
                        ),
                    lineWidth: 2
                )
                .frame(width: 260, height: 260)
                .shadow(color: palette.glow.opacity(connected ? 0.7 : 0.2), radius: 12)
                .animation(.easeInOut(duration: 0.6), value: connected)

            if connecting {
                SpinningArc(period: 1.3, length: 0.3, color: palette.light)
                    .frame(width: 260, height: 260)
            } else if !connected {
                SpinningArc(period: 18, length: 0.07, color: Theme.goldLight)
                    .frame(width: 260, height: 260)
            }

            Circle()
                .fill(Theme.goldLight)
                .frame(width: 5, height: 5)
                .offset(y: -145)
        }
    }

    private var core: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.main.opacity(0.7), palette.main.opacity(0.22), Color.clear],
                        center: .center, startRadius: 4, endRadius: 118
                    )
                )
                .frame(width: 236, height: 236)
                .blur(radius: 8)

            VStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, palette.light], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: palette.glow, radius: 9)
                    .symbolEffect(.pulse, isActive: connecting)
                Text(label)
                    .font(Theme.label(15))
                    .tracking(3)
                    .foregroundColor(Theme.text)
            }
            .frame(width: 226, height: 226)
            .liquidGlass(Circle(), tint: palette.main.opacity(0.16), interactive: true)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.clear, Color.white.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: 226, height: 226)
            )
        }
    }
}
