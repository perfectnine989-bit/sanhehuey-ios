import CoreMotion
import SwiftUI
import UIKit

/// Наклон телефона для эффекта глубины.
final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let nx = CGFloat(max(-0.5, min(0.5, motion.attitude.roll)))
            let ny = CGFloat(max(-0.5, min(0.5, motion.attitude.pitch - 1.0)))
            self.x += (nx - self.x) * 0.12
            self.y += (ny - self.y) * 0.12
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

struct SceneBackground: View {
    let palette: Palette
    let isOn: Bool
    @StateObject private var motion = MotionManager()

    private var hasBackdrop: Bool { UIImage(named: "backdrop") != nil }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg

                if hasBackdrop {
                    Image("backdrop")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.08)
                        .offset(x: -motion.x * 14, y: -motion.y * 10)
                        .clipped()
                        .opacity(0.9)
                }

                RadialGradient(
                    colors: [palette.main.opacity(0.22), Color.clear],
                    center: UnitPoint(x: 0.2, y: 0.05),
                    startRadius: 10, endRadius: geo.size.height * 0.55
                )
                RadialGradient(
                    colors: [palette.main.opacity(0.14), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 10, endRadius: geo.size.width * 0.95
                )

                NeonSign(color: palette.glow, lit: isOn)
                    .position(x: geo.size.width * 0.10, y: geo.size.height * 0.30)
                    .offset(x: motion.x * 12, y: motion.y * 7)

                DragonAura(palette: palette, size: geo.size)
                    .offset(x: -motion.x * 24, y: -motion.y * 16)

                SmokeLayer()

                EmberField(color: palette.light, glow: palette.glow)
                    .offset(x: -motion.x * 6, y: -motion.y * 4)

                // Затемнение сверху (чтобы название читалось) и снизу (чтобы читались карточки)
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2)
                )
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.65)],
                    startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.75)],
                    center: .center,
                    startRadius: geo.size.width * 0.45, endRadius: geo.size.height * 0.78
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .animation(.easeInOut(duration: 1.0), value: palette.glow)
    }
}

// MARK: - Дракон-аура

struct DragonAura: View {
    let palette: Palette
    let size: CGSize
    @State private var breathe = false

    private var dragonHeight: CGFloat { size.height * 0.92 }

    private var dragon: some View {
        Image("dragon_hi")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: dragonHeight / 2, height: dragonHeight)
    }

    var body: some View {
        ZStack {
            dragon
                .foregroundStyle(palette.glow)
                .blur(radius: 26)
                .opacity(breathe ? 0.38 : 0.18)
                .blendMode(.plusLighter)

            dragon
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.light.opacity(0.9), palette.main.opacity(0.6), palette.main.opacity(0.28)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(0.40)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let p = CGFloat(fract(t / 8.0))
                dragon
                    .foregroundStyle(Color.white)
                    .mask(
                        LinearGradient(
                            colors: [Color.clear, Color.white, Color.clear],
                            startPoint: UnitPoint(x: p * 2.4 - 0.9, y: p * 2.4 - 0.9),
                            endPoint: UnitPoint(x: p * 2.4 - 0.3, y: p * 2.4 - 0.3)
                        )
                    )
                    .opacity(0.45)
                    .blendMode(.plusLighter)
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: Color.white, location: 0.0),
                    .init(color: Color.white, location: 0.5),
                    .init(color: Color.white.opacity(0.18), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .position(x: size.width * 0.52, y: size.height * 0.56)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Неоновая вывеска (ярче, когда VPN включён)

struct NeonSign: View {
    let color: Color
    let lit: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let flicker = 0.84 + 0.16 * sin(t * 3.1) * sin(t * 1.7 + 1.3)
            let level = lit ? flicker : 0.28
            VStack(spacing: 3) {
                ForEach(["三", "和", "会"], id: \.self) { glyph in
                    Text(glyph)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                }
            }
            .foregroundColor(Color.white.opacity(0.92))
            .shadow(color: color, radius: 3)
            .shadow(color: color, radius: 9)
            .shadow(color: color.opacity(0.7), radius: 20)
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(color, lineWidth: 1.6)
                    .shadow(color: color, radius: 6)
            )
            .opacity(level)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Дым

struct SmokeLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Image("smoke")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.3)
                .offset(x: CGFloat(sin(t * 0.15)) * 34, y: CGFloat(cos(t * 0.11)) * 24)
                .opacity(0.16)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Искры: тонкие, неяркие, летят вверх

private func emberPoint(_ tt: Double, _ speed: Double, _ phase: Double, _ x0: Double, _ sway: Double, _ seed: Double, _ area: CGSize) -> CGPoint {
    let p = fract(tt * speed + phase)
    let x = (x0 + sin(tt * 0.9 + seed) * sway) * Double(area.width)
    let y = Double(area.height) * (1.02 - p * 1.1)
    return CGPoint(x: x, y: y)
}

struct EmberField: View {
    let color: Color
    let glow: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, area in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ctx.blendMode = .plusLighter

                for i in 0..<28 {
                    let seed = Double(i) * 12.9898
                    let speed = 0.045 + fract(sin(seed) * 43758.5453) * 0.07
                    let phase = fract(sin(seed * 1.7) * 24634.6345)
                    let x0 = fract(sin(seed * 3.1) * 13758.5453)
                    let sway = 0.03 + fract(sin(seed * 2.3) * 7919.1) * 0.05
                    let thick = 0.5 + fract(sin(seed * 5.3) * 9758.5) * 1.0
                    let big = i % 12 == 0

                    let head = emberPoint(t, speed, phase, x0, sway, seed, area)
                    let tail = emberPoint(t - 0.4, speed, phase, x0, sway, seed, area)

                    let progress = fract(t * speed + phase)
                    let fade = pow(sin(progress * Double.pi), 0.8)
                    let twinkle = 0.5 + 0.5 * sin(t * (5 + fract(seed) * 6) + seed)
                    let a = fade * twinkle * 0.55

                    var path = Path()
                    path.move(to: tail)
                    path.addLine(to: head)

                    ctx.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [glow.opacity(0), color.opacity(a * 0.8)]),
                            startPoint: tail, endPoint: head
                        ),
                        style: StrokeStyle(lineWidth: thick * 1.5, lineCap: .round)
                    )
                    ctx.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [Color.white.opacity(0), Color.white.opacity(a)]),
                            startPoint: tail, endPoint: head
                        ),
                        style: StrokeStyle(lineWidth: thick * 0.6, lineCap: .round)
                    )

                    if big {
                        let r = 3.5 + thick
                        let rect = CGRect(x: head.x - r, y: head.y - r, width: r * 2, height: r * 2)
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [Color.white.opacity(a), glow.opacity(a * 0.4), Color.clear]),
                                center: head, startRadius: 0, endRadius: r
                            )
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
