import SwiftUI
import UIKit

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.7), value: configuration.isPressed)
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
                        .stroke(color.opacity((1 - p) * 0.30), lineWidth: 1.2)
                        .frame(width: 266, height: 266)
                        .scaleEffect(1.0 + CGFloat(p) * 0.2)
                }
            }
            .opacity(active ? 1 : 0)
            .animation(.easeInOut(duration: 0.6), value: active)
        }
        .allowsHitTesting(false)
    }
}

/// Комета: плавный градиентный хвост, яркая головка и мягкое свечение.
struct CometRing: View {
    let color: Color
    let length: CGFloat
    let period: Double
    let width: CGFloat
    let diameter: CGFloat
    @State private var spin = false

    private var tail: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: color.opacity(0), location: 0),
                .init(color: color.opacity(0.25), location: length * 0.55),
                .init(color: color, location: length)
            ]),
            center: .center
        )
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: length)
            .stroke(tail, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    var body: some View {
        let theta = Double(length) * 2.0 * Double.pi
        let hx = CGFloat(cos(theta)) * diameter / 2
        let hy = CGFloat(sin(theta)) * diameter / 2

        ZStack {
            arc
                .blur(radius: 8)
                .blendMode(.plusLighter)
            arc
            Circle()
                .fill(Color.white)
                .frame(width: width + 1.5, height: width + 1.5)
                .shadow(color: color, radius: 5)
                .shadow(color: color.opacity(0.8), radius: 12)
                .offset(x: hx, y: hy)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(spin ? 360 : 0))
        .animation(.linear(duration: period).repeatForever(autoreverses: false), value: spin)
        .onAppear { spin = true }
    }
}

struct PowerButton: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette
    @State private var breathe = false

    private let d: CGFloat = 258

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
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    // MARK: Кольцо

    private var ring: some View {
        ZStack {
            // тонкая золотая рамка снаружи
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Theme.goldLight.opacity(0.55), Theme.gold.opacity(0.06), Theme.gold.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .frame(width: d + 30, height: d + 30)

            tube

            if connected {
                litRing
            } else if connecting {
                CometRing(color: palette.light, length: 0.66, period: 1.15, width: 4, diameter: d)
            } else {
                CometRing(color: Theme.goldLight, length: 0.30, period: 9, width: 3.2, diameter: d)
            }
        }
    }

    /// Стеклянная трубка: тёмное тело, кромки света сверху-слева и внутренняя тень.
    private var tube: some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.38), lineWidth: 11)
            Circle().stroke(Color.white.opacity(0.06), lineWidth: 11)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.03), Color.white.opacity(0.16)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: d + 11, height: d + 11)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.white.opacity(0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: d - 11, height: d - 11)
        }
        .frame(width: d, height: d)
    }

    /// Подключено: кольцо горит целиком и дышит.
    private var litRing: some View {
        let gradient = AngularGradient(
            colors: [palette.main, palette.light, palette.main, palette.light, palette.main],
            center: .center
        )
        return ZStack {
            Circle().stroke(gradient, lineWidth: 6).blur(radius: 9).blendMode(.plusLighter)
            Circle().stroke(gradient, lineWidth: 3.2)
        }
        .frame(width: d, height: d)
        .opacity(breathe ? 1 : 0.78)
        .transition(.opacity)
    }

    // MARK: Центр

    private var core: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.main.opacity(0.65), palette.main.opacity(0.2), Color.clear],
                        center: .center, startRadius: 4, endRadius: 112
                    )
                )
                .frame(width: 226, height: 226)
                .blur(radius: 8)

            VStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 48, weight: .light))
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
            .frame(width: 216, height: 216)
            .liquidGlass(Circle(), tint: palette.main.opacity(0.14), interactive: true)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.clear, Color.white.opacity(0.14)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
                    .frame(width: 216, height: 216)
            )
        }
    }
}
