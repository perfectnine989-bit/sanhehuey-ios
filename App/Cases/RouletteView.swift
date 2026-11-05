import SwiftUI
import UIKit

// MARK: - Вспомогательное

/// Кривая cubic-bezier(.12,.70,.15,1), как у рулетки на сайте.
enum Bezier {
    static func ease(_ x: Double, _ x1: Double = 0.12, _ y1: Double = 0.70, _ x2: Double = 0.15, _ y2: Double = 1.0) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var lo = 0.0
        var hi = 1.0
        var t = x
        for _ in 0..<28 {
            let cx = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
            if abs(cx - x) < 1e-5 { break }
            if cx < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
    }
}

final class FrameDriver: NSObject {
    private var link: CADisplayLink?
    private var handler: ((CFTimeInterval) -> Void)?

    func start(_ handler: @escaping (CFTimeInterval) -> Void) {
        stop()
        self.handler = handler
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func step(_ l: CADisplayLink) { handler?(l.timestamp) }

    func stop() {
        link?.invalidate()
        link = nil
        handler = nil
    }
}

struct Pointer: Shape {
    var up: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Модель рулетки

@MainActor
final class RouletteModel: ObservableObject {
    enum Phase { case confirm, loading, spinning, result, failed }

    let def: CaseDef
    let kind: OpenKind
    @Published var phase: Phase = .confirm
    @Published var items: [Prize] = []
    @Published var offset: CGFloat = 0
    @Published var result: Prize?
    @Published var expires = ""
    @Published var banner = ""
    @Published var errorText = ""

    var viewport: CGFloat = 390
    let itemW: CGFloat = 130
    private let winIndex = 53
    private let driver = FrameDriver()
    private var lastIndex = 0
    private var lastHaptic: CFTimeInterval = 0
    private var lastSound: CFTimeInterval = 0

    init(def: CaseDef, kind: OpenKind) {
        self.def = def
        self.kind = kind
        items = Self.randomReel(def.prizes)
    }

    static func randomReel(_ prizes: [Prize]) -> [Prize] {
        let pool = prizes.isEmpty ? [Prize(name: "Приз", rarity: .common, days: 0, chance: 0)] : prizes
        return (0..<60).map { _ in pool.randomElement()! }
    }

    func cancel() { driver.stop() }

    private func reshuffle() {
        items = Self.randomReel(def.prizes)
        offset = 0
    }

    // MARK: запрос

    private struct OpenResult {
        var prize: Prize
        var balance: Double?
        var expires: String
        var wasReroll: Bool
    }

    private func call() async throws -> OpenResult {
        let r: [String: Any]
        switch kind {
        case .paid: r = try await SiteAPI.shared.jsonOK("/api/cases/open", method: "POST", body: ["case_type": def.id])
        case .free: r = try await SiteAPI.shared.jsonOK("/api/cases/free", method: "POST")
        case .referral: r = try await SiteAPI.shared.jsonOK("/api/referral/open", method: "POST", body: ["case_type": def.id])
        }
        guard let p = r["prize"] as? [String: Any] else { throw APIError("Сервер не вернул приз") }
        return OpenResult(
            prize: Prize(json: p),
            balance: r["balance"].map { jNum($0) },
            expires: jStr(r["expires_at"]),
            wasReroll: jBool(r["was_reroll"])
        )
    }

    // MARK: сценарий

    func confirm(_ site: SiteSession) async {
        guard phase == .confirm else { return }
        phase = .loading
        SoundEngine.shared.play(.open)
        Haptics.heavyTap()
        let started = Date()
        do {
            let res = try await call()
            let wait = 0.75 - Date().timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            if let b = res.balance { site.balance = b }
            expires = res.expires
            phase = .spinning
            SoundEngine.shared.play(.whoosh)

            if res.wasReroll {
                await spin(to: Prize(name: "Второй шанс", rarity: .rare, days: -1, chance: 0))
                banner = "ВТОРОЙ ШАНС"
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                reshuffle()
                SoundEngine.shared.play(.whoosh)
                await spin(to: res.prize)
            } else if res.prize.days == -1 {
                await spin(to: res.prize)
                banner = "ВТОРОЙ ШАНС"
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                let again = try await SiteAPI.shared.jsonOK("/api/cases/open", method: "POST", body: ["case_type": def.id, "is_reroll": true])
                guard let p = again["prize"] as? [String: Any] else { throw APIError("Сервер не вернул приз") }
                if let b = again["balance"] { site.balance = jNum(b) }
                expires = jStr(again["expires_at"])
                reshuffle()
                SoundEngine.shared.play(.whoosh)
                await spin(to: Prize(json: p))
            } else {
                await spin(to: res.prize)
            }
            finish()
        } catch {
            errorText = error.localizedDescription
            phase = .failed
            SoundEngine.shared.play(.error)
            Haptics.error()
        }
    }

    private func spin(to prize: Prize) async {
        result = prize
        var reel = items
        reel[winIndex] = prize
        items = reel
        offset = 0

        let w = itemW
        let center = viewport / 2 - w / 2
        let target = -(CGFloat(winIndex) * w - center + Self.fairJitter() * w)
        lastIndex = Int(floor((viewport / 2) / w))
        let duration = 6.4
        let start = CACurrentMediaTime()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            driver.start { [weak self] now in
                guard let self else { return }
                let t = min(1.0, (now - start) / duration)
                self.offset = target * CGFloat(Bezier.ease(t))
                let idx = Int(floor((self.viewport / 2 - self.offset) / w))
                if idx != self.lastIndex {
                    self.lastIndex = idx
                    self.tick(remaining: self.winIndex - idx, now: now)
                }
                if t >= 1.0 {
                    self.driver.stop()
                    cont.resume()
                }
            }
        }
    }

    /// Каждый шаг карточки через центр: звук и вибрация. К концу тики становятся тяжелее.
    private func tick(remaining: Int, now: CFTimeInterval) {
        let heavy = remaining <= 5
        if now - lastSound > 0.02 {
            lastSound = now
            SoundEngine.shared.play(
                heavy ? .tickHeavy : .tick,
                volume: heavy ? 1.0 : 0.7,
                rate: heavy ? 1.0 : Float.random(in: 0.95...1.08)
            )
        }
        if now - lastHaptic > (heavy ? 0.0 : 0.045) {
            lastHaptic = now
            Haptics.tick(fast: !heavy)
        }
    }

    static func fairJitter() -> CGFloat {
        let roll = Double.random(in: 0..<1)
        let side: Double = Bool.random() ? -1 : 1
        let amount: Double
        if roll < 0.60 {
            amount = Double.random(in: 0..<0.16)
        } else if roll < 0.90 {
            amount = 0.16 + Double.random(in: 0..<0.14)
        } else {
            amount = 0.30 + Double.random(in: 0..<0.10)
        }
        return CGFloat(side * amount)
    }

    private func finish() {
        guard let r = result else { return }
        phase = .result
        let sound: Sound
        switch r.rarity {
        case .common: sound = .winCommon
        case .uncommon: sound = .winUncommon
        case .rare: sound = .winRare
        case .epic: sound = .winEpic
        case .legendary: sound = .winLegendary
        }
        SoundEngine.shared.play(sound)
        Haptics.win(r.rarity)
    }

    func subtitle(for p: Prize) -> String {
        let lower = p.name.lowercased()
        if p.days == -1 { return "Вам выпал Второй шанс, крутим снова!" }
        if p.manual != nil || (p.days == 0 && lower.contains("premium")) { return "Ожидайте выдачи в течение 24 часов" }
        if lower.contains("баланс") || lower.contains("₽") { return "Зачислено на баланс" }
        if p.days == 730 || lower.contains("безлимит") { return "Безлимитный VPN навсегда" }
        return "+\(p.days) дней VPN" + (expires.isEmpty ? "" : " · подписка до \(expires)")
    }
}

// MARK: - Эффекты

struct ConfettiView: View {
    let colors: [Color]
    private let particles: [Particle]
    @State private var start = Date()

    struct Particle {
        let angle: Double
        let speed: Double
        let size: CGFloat
        let spin: Double
        let color: Int
        let delay: Double
    }

    init(colors: [Color], count: Int = 130) {
        self.colors = colors
        particles = (0..<count).map { _ in
            Particle(
                angle: Double.random(in: 0..<(2 * Double.pi)),
                speed: Double.random(in: 160...520),
                size: CGFloat.random(in: 7...15),
                spin: Double.random(in: -12...12),
                color: Int.random(in: 0..<max(colors.count, 1)),
                delay: Double.random(in: 0...0.25)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let tt = t - p.delay
                    if tt < 0 || tt > 3.2 { continue }
                    let vx = cos(p.angle) * p.speed
                    let vy = sin(p.angle) * p.speed - 280
                    let x = Double(size.width) / 2 + vx * tt
                    let y = Double(size.height) * 0.42 + vy * tt + 0.5 * 720 * tt * tt
                    var c = ctx
                    c.opacity = max(0, 1 - tt / 3.2)
                    c.translateBy(x: CGFloat(x), y: CGFloat(y))
                    c.rotate(by: .radians(p.spin * tt))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colors[p.color % max(colors.count, 1)]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct RaysView: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let r = max(size.width, size.height)
                for i in 0..<14 {
                    let a = Double(i) / 14.0 * 2.0 * Double.pi + t * 0.25
                    var path = Path()
                    path.move(to: c)
                    path.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - 0.09)) * r, y: c.y + CGFloat(sin(a - 0.09)) * r))
                    path.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 0.09)) * r, y: c.y + CGFloat(sin(a + 0.09)) * r))
                    path.closeSubpath()
                    ctx.fill(
                        path,
                        with: .radialGradient(Gradient(colors: [color.opacity(0.4), Color.clear]), center: c, startRadius: 0, endRadius: r * 0.7)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ReelItem: View {
    let prize: Prize

    var body: some View {
        VStack(spacing: 6) {
            PrizeImage(name: prize.name, days: prize.days, size: 84)
            Text(prize.name)
                .font(Theme.body(11))
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30)
        }
        .padding(.vertical, 10)
        .frame(width: 116, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color.black.opacity(0.55), prize.rarity.color.opacity(0.28)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(prize.rarity.color.opacity(0.7), lineWidth: 1.2)
        )
        .shadow(color: prize.rarity.color.opacity(0.3), radius: 8)
        .frame(width: 130, height: 170)
    }
}

// MARK: - Экран рулетки

struct RouletteView: View {
    let request: RouletteRequest
    let onTake: (Prize) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var site: SiteSession
    @StateObject private var model: RouletteModel
    @State private var pop = false
    @State private var flash = false

    init(request: RouletteRequest, onTake: @escaping (Prize) -> Void) {
        self.request = request
        self.onTake = onTake
        _model = StateObject(wrappedValue: RouletteModel(def: request.def, kind: request.kind))
    }

    private var theme: CaseTheme { CaseThemes.theme(request.def.id) }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                reel
                Spacer(minLength: 0)
                bottom
            }
            .padding(.bottom, 24)

            if model.phase == .result, let prize = model.result {
                resultOverlay(prize)
                    .transition(.opacity)
                if prize.rarity == .epic || prize.rarity == .legendary {
                    ConfettiView(colors: [Color(hex: 0xE8C173), Color(hex: 0xC9A15A), Theme.jade, Color.white, prize.rarity.color])
                }
            }

            Color.white.opacity(flash ? 0.0 : 0.85)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(model.phase == .result && model.result?.rarity == .legendary ? 1 : 0)
        }
        .onAppear { Haptics.prepare() }
        .onDisappear { model.cancel() }
        .onChange(of: model.phase) { _, phase in
            if phase == .result {
                pop = false
                flash = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { pop = true }
                withAnimation(.easeOut(duration: 0.9)) { flash = true }
            }
        }
        .interactiveDismissDisabled(model.phase == .spinning || model.phase == .loading)
    }

    // MARK: части

    private var background: some View {
        ZStack {
            Color.black
            Image(theme.poster)
                .resizable()
                .scaledToFill()
                .blur(radius: 26)
                .opacity(0.35)
            LinearGradient(colors: [theme.deep.opacity(0.7), theme.surface.opacity(0.95), Color.black], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .frame(width: 42, height: 42)
                    .liquidGlass(Circle(), tint: Color.black.opacity(0.3), interactive: true)
            }
            .buttonStyle(.plain)
            .opacity(model.phase == .spinning || model.phase == .loading ? 0 : 1)
            Spacer()
            VStack(spacing: 3) {
                Text(model.banner.isEmpty ? request.def.name : model.banner)
                    .font(Theme.hero(22))
                    .foregroundStyle(LinearGradient(colors: [Color.white, theme.accent], startPoint: .top, endPoint: .bottom))
                Text("ОФИЦИАЛЬНЫЕ ШАНСЫ")
                    .font(Theme.label(10))
                    .tracking(4)
                    .foregroundColor(Theme.goldDim)
            }
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var reel: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    ForEach(Array(model.items.enumerated()), id: \.offset) { _, prize in
                        ReelItem(prize: prize)
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .offset(x: model.offset)

                // стеклянная линза по центру
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 134, height: 176)
                    .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: theme.accent.opacity(0.10))
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(LinearGradient(colors: [Color.clear, theme.accent, Color.clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2)
                    .shadow(color: theme.accent, radius: 8)
                    .allowsHitTesting(false)

                VStack {
                    Pointer(up: false).fill(theme.accent).frame(width: 16, height: 11).shadow(color: theme.accent, radius: 6)
                    Spacer()
                    Pointer(up: true).fill(theme.accent).frame(width: 16, height: 11).shadow(color: theme.accent, radius: 6)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: 190)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.black, location: 0.12),
                        .init(color: Color.black, location: 0.88),
                        .init(color: Color.clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .onAppear { model.viewport = geo.size.width }
            .onChange(of: geo.size.width) { _, w in model.viewport = w }
        }
        .frame(height: 190)
    }

    @ViewBuilder
    private var bottom: some View {
        switch model.phase {
        case .confirm:
            VStack(spacing: 12) {
                Text(request.kind == .paid ? "Стоимость: \(Int(request.def.price)) ₽" : "Бесплатное открытие")
                    .font(Theme.body(15))
                    .foregroundColor(Theme.muted)
                Button {
                    Task { await model.confirm(site) }
                } label: {
                    Text(request.kind == .paid ? "Открыть кейс" : "Получить дань")
                        .font(Theme.title(18))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .liquidGlass(Capsule(), tint: theme.accent.opacity(0.5), interactive: true)
                }
                .buttonStyle(.plain)
                Button("Отмена") { dismiss() }
                    .font(Theme.body(15))
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 28)
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(theme.accent)
                Text("Открываем…")
                    .font(Theme.title(16))
                    .foregroundColor(Theme.text)
            }
        case .spinning:
            Text("КРУТИТСЯ")
                .font(Theme.title(16))
                .tracking(6)
                .foregroundColor(theme.accent)
                .opacity(0.9)
        case .failed:
            VStack(spacing: 12) {
                Text(model.errorText)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.crimson)
                    .multilineTextAlignment(.center)
                Button("Закрыть") { dismiss() }
                    .font(Theme.title(16))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .liquidGlass(Capsule(), tint: Color.black.opacity(0.3), interactive: true)
            }
            .padding(.horizontal, 28)
        case .result:
            Color.clear.frame(height: 1)
        }
    }

    private func resultOverlay(_ prize: Prize) -> some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()
            RaysView(color: prize.rarity.color)
                .blendMode(.plusLighter)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("\(prize.rarity.title.uppercased()) · \(prize.rarity.label.uppercased())")
                    .font(Theme.label(12))
                    .tracking(4)
                    .foregroundColor(prize.rarity.color)

                PrizeImage(name: prize.name, days: prize.days, size: 190)
                    .shadow(color: prize.rarity.color.opacity(0.85), radius: 34)
                    .scaleEffect(pop ? 1 : 0.15)
                    .rotationEffect(.degrees(pop ? 0 : -25))

                Text(prize.name)
                    .font(Theme.hero(30))
                    .foregroundStyle(LinearGradient(colors: [Color.white, prize.rarity.color], startPoint: .top, endPoint: .bottom))
                    .shadow(color: prize.rarity.color.opacity(0.8), radius: 16)
                    .multilineTextAlignment(.center)
                    .scaleEffect(pop ? 1 : 0.6)

                Text(model.subtitle(for: prize))
                    .font(Theme.body(15))
                    .foregroundColor(Theme.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    onTake(prize)
                    dismiss()
                } label: {
                    Text("Забрать приз")
                        .font(Theme.title(17))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .liquidGlass(Capsule(), tint: prize.rarity.color.opacity(0.5), interactive: true)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            }
        }
    }
}
