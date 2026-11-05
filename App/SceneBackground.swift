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
                    colors: [palette.main.opacity(0.30), Color.clear],
                    center: UnitPoint(x: 0.2, y: 0.05),
                    startRadius: 10, endRadius: geo.size.height * 0.55
                )
                RadialGradient(
                    colors: [palette.main.opacity(0.20), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.40),
                    startRadius: 10, endRadius: geo.size.width * 0.95
                )

                BokehLights(color: palette.glow)
                    .offset(x: motion.x * 8, y: motion.y * 5)

                NeonSign(color: palette.glow)
                    .position(x: geo.size.width * 0.12, y: geo.size.height * 0.2)
                    .offset(x: motion.x * 12, y: motion.y * 7)

                DragonAura(palette: palette, size: geo.size)
                    .offset(x: -motion.x * 24, y: -motion.y * 16)

                SmokeLayer()

                EmberField(color: palette.light)
                    .offset(x: -motion.x * 6, y: -motion.y * 4)

                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
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

    private var dragonHeight: CGFloat { size.height * 0.98 }

    private var dragon: some View {
        Image("dragon_hi")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: dragonHeight / 2, height: dragonHeight)
    }

    var body: some View {
        ZStack {
            // Дальнее свечение (дышит)
            dragon
                .foregroundStyle(palette.glow)
                .blur(radius: 28)
                .opacity(breathe ? 0.60 : 0.32)
                .blendMode(.plusLighter)

            // Сам рисунок
            dragon
                .foregroundStyle(
                    LinearGradient(
                        colors: [palette.light.opacity(0.95), palette.main.opacity(0.65), palette.main.opacity(0.30)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(0.55)

            // Блик, пробегающий по чешуе
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
                    .opacity(0.7)
                    .blendMode(.plusLighter)
            }
        }
        .position(x: size.width * 0.52, y: size.height * 0.5)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Огни города

struct BokehLights: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let spots: [(CGFloat, CGFloat, CGFloat, Double)] = [
                (0.08, 0.10, 22, 0.55), (0.20, 0.06, 14, 0.45), (0.30, 0.16, 26, 0.35),
                (0.05, 0.28, 18, 0.40), (0.24, 0.30, 12, 0.50), (0.36, 0.08, 10, 0.50),
                (0.12, 0.40, 20, 0.30), (0.42, 0.24, 16, 0.30), (0.62, 0.05, 12, 0.30),
                (0.90, 0.10, 18, 0.35), (0.78, 0.18, 10, 0.30)
            ]
            for spot in spots {
                let r = spot.2
                let rect = CGRect(x: spot.0 * size.width - r, y: spot.1 * size.height - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(spot.3)))
            }
        }
        .blur(radius: 7)
        .allowsHitTesting(false)
    }
}

// MARK: - Неоновая вывеска

struct NeonSign: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let flicker = 0.84 + 0.16 * sin(t * 3.1) * sin(t * 1.7 + 1.3)
            VStack(spacing: 4) {
                ForEach(["三", "和", "会"], id: \.self) { glyph in
                    Text(glyph)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                }
            }
            .foregroundColor(Color.white.opacity(0.92))
            .shadow(color: color, radius: 4)
            .shadow(color: color, radius: 12)
            .shadow(color: color.opacity(0.7), radius: 26)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 2)
                    .shadow(color: color, radius: 8)
            )
            .opacity(flicker)
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
                .opacity(0.22)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Угольки

struct EmberField: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<46 {
                    let seed = Double(i) * 12.9898
                    let speed = 0.03 + fract(sin(seed) * 43758.5453) * 0.05
                    let phase = fract(sin(seed * 1.7) * 24634.6345)
                    let progress = fract(t * speed + phase)
                    let x0 = fract(sin(seed * 3.1) * 13758.5453)
                    let x = (x0 + sin(t * 0.6 + seed) * 0.03) * Double(size.width)
                    let y = Double(size.height) * (1.02 - progress * 1.1)
                    let r = 1.1 + fract(sin(seed * 5.3) * 9758.5) * 2.0
                    let alpha = sin(progress * Double.pi) * 0.9

                    let glow = CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)
                    ctx.fill(Path(ellipseIn: glow), with: .color(color.opacity(alpha * 0.18)))
                    let core = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: core), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
