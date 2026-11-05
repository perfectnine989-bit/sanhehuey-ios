import SafariServices
import SwiftUI

enum OpenKind {
    case paid, free, referral
}

struct RouletteRequest: Identifiable {
    let id = UUID()
    let def: CaseDef
    let kind: OpenKind
}

struct PayLink: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Лёгкий наклон карточки от поворота телефона. Обновляет только себя, а не весь экран.
struct Tilt: ViewModifier {
    @ObservedObject var motion: MotionManager

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(Double(motion.x) * 7), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-motion.y) * 6), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
    }
}

struct Shimmer: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = CGFloat(fract(t / 5.5))
            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, color.opacity(0.30), Color.white.opacity(0.18), Color.clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.5)
                    .rotationEffect(.degrees(18))
                    .offset(x: -geo.size.width * 0.5 + p * geo.size.width * 2.0)
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
}

struct CasesScreen: View {
    @EnvironmentObject var site: SiteSession
    @StateObject private var store = CasesStore()
    @StateObject private var motion = MotionManager()

    @State private var roulette: RouletteRequest?
    @State private var chances: CaseDef?
    @State private var showTopUp = false
    @State private var topUpNeed: Double?
    @State private var pendingPrize: Prize?
    @State private var manualReward: ManualReward?
    @State private var showPremium = false
    @State private var toast: String?

    private func freeLabel() -> String? {
        guard let last = site.dailyCaseLast else { return nil }
        let diff = last.addingTimeInterval(7 * 86400).timeIntervalSinceNow
        if diff <= 0 { return nil }
        let d = Int(diff) / 86400
        let h = (Int(diff) % 86400) / 3600
        let m = (Int(diff) % 3600) / 60
        return d > 0 ? "\(d)д \(h)ч" : "\(h)ч \(m)м"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    titleBlock
                    balanceBar
                    if !site.isLoggedIn { loginCard }

                    ForEach(Array(store.defs.enumerated()), id: \.element.id) { index, def in
                        CaseCard(
                            def: def,
                            freeLabel: def.id == "free" ? freeLabel() : nil,
                            motion: motion,
                            index: index,
                            onOpen: { open(def) },
                            onPeek: { chances = def }
                        )
                    }

                    historyBlock
                    BrotherhoodView(store: store) { id in
                        if let def = store.defs.first(where: { $0.id == id }) {
                            roulette = RouletteRequest(def: def, kind: .referral)
                        }
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
            .refreshable { await reload() }

            if let toast {
                Text(toast)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .liquidGlass(Capsule(), tint: Color.black.opacity(0.4))
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await reload() }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .fullScreenCover(item: $roulette, onDismiss: afterRoulette) { request in
            RouletteView(request: request) { prize in pendingPrize = prize }
        }
        .sheet(item: $chances) { def in ChancesSheet(def: def) }
        .sheet(isPresented: $showTopUp) { TopUpSheet(need: topUpNeed) }
        .sheet(item: Binding(get: { manualReward.map { ManualBox(reward: $0) } }, set: { if $0 == nil { manualReward = nil } })) { box in
            ManualRewardSheet(reward: box.reward)
        }
        .sheet(isPresented: $showPremium) { PremiumClaimSheet() }
    }

    private func reload() async {
        await site.refresh()
        await store.load()
        await store.loadHistory()
        await store.loadReferral()
    }

    private func afterRoulette() {
        Task { await reload() }
        guard let prize = pendingPrize else { return }
        pendingPrize = nil
        if let manual = prize.manual {
            manualReward = manual
        } else if prize.days == 0 && prize.name.lowercased().contains("premium") {
            showPremium = true
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    private func open(_ def: CaseDef) {
        guard site.isLoggedIn else {
            Haptics.warn()
            showToast("Сначала войди через Telegram")
            Task { await site.startTelegramLogin() }
            return
        }
        if def.id == "free" {
            if let left = freeLabel() {
                Haptics.warn()
                SoundEngine.shared.play(.error)
                showToast("Следующая дань через \(left)")
                return
            }
            roulette = RouletteRequest(def: def, kind: .free)
        } else {
            if site.balance < def.price {
                Haptics.warn()
                SoundEngine.shared.play(.error)
                topUpNeed = def.price - site.balance
                showTopUp = true
                return
            }
            roulette = RouletteRequest(def: def, kind: .paid)
        }
    }

    // MARK: блоки

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("КАЗИНО СЕМЬИ")
                .font(Theme.label(12))
                .tracking(6)
                .foregroundColor(Theme.goldDim)
            Text("Кейсы")
                .font(Theme.hero(34))
                .foregroundStyle(Theme.goldGradient)
            Text("Крути и выигрывай: дни, месяцы и годы VPN, Telegram Premium. В Top G реально выбить безлимит. Все шансы открыты.")
                .font(Theme.body(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var balanceBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ВАШ БАЛАНС")
                    .font(Theme.label(11))
                    .tracking(3)
                    .foregroundColor(Theme.goldDim)
                Text("\(Int(site.balance.rounded())) ₽")
                    .font(Theme.digits(26))
                    .foregroundStyle(Theme.goldGradient)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: site.balance)
            }
            Spacer()
            Button {
                topUpNeed = nil
                showTopUp = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Пополнить")
                }
                .font(Theme.title(14))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.22), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .liquidGlass(RoundedRectangle(cornerRadius: 26, style: .continuous), tint: Color.black.opacity(0.25))
    }

    private var loginCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.goldGradient)
            Text("Войди, чтобы открывать кейсы")
                .font(Theme.title(17))
                .foregroundColor(Theme.text)
            Text("Вход через Telegram, как на сайте: баланс, призы и история будут общими.")
                .font(Theme.body(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
            LoginButton()
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .liquidGlass(RoundedRectangle(cornerRadius: 26, style: .continuous), tint: Color.black.opacity(0.25))
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "ИСТОРИЯ КРУТОК")
            if store.history.isEmpty {
                Text("Пока пусто. Открой первый кейс!")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.muted)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.history.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 12) {
                            PrizeImage(name: row.prize, days: 1, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.prize)
                                    .font(Theme.title(14))
                                    .foregroundColor(Theme.text)
                                Text(CaseThemes.defaultName(row.caseId))
                                    .font(Theme.body(11))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                            Text(row.date)
                                .font(Theme.body(11))
                                .foregroundColor(Theme.muted)
                        }
                        .padding(.vertical, 10)
                        if i < store.history.count - 1 {
                            Rectangle().fill(Theme.goldDim.opacity(0.16)).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: Color.black.opacity(0.22))
            }
        }
    }
}

struct ManualBox: Identifiable {
    let id = UUID()
    let reward: ManualReward
}

/// Кнопка входа через Telegram с состоянием ожидания.
struct LoginButton: View {
    @EnvironmentObject var site: SiteSession
    var link = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.heavyTap()
                Task { await site.startTelegramLogin(link: link) }
            } label: {
                HStack(spacing: 10) {
                    if site.login == .waiting {
                        ProgressView().tint(Theme.text)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(site.login == .waiting ? "Жду подтверждения в Telegram…" : (link ? "Привязать Telegram" : "Войти через Telegram"))
                }
                .font(Theme.title(15))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .liquidGlass(Capsule(), tint: Color(hex: 0x2AABEE).opacity(0.32), interactive: true)
            }
            .buttonStyle(.plain)

            if site.login == .waiting {
                Text("Открой Telegram и нажми Start у бота, потом вернись сюда.")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            if case .failed(let text) = site.login {
                Text(text)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.crimson)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Карточка кейса

struct CaseCard: View {
    let def: CaseDef
    let freeLabel: String?
    let motion: MotionManager
    let index: Int
    let onOpen: () -> Void
    let onPeek: () -> Void

    @State private var appeared = false
    @State private var zoom = false

    private var theme: CaseTheme { CaseThemes.theme(def.id) }
    private var isFree: Bool { def.id == "free" }

    var body: some View {
        card
            .modifier(Tilt(motion: motion))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 36)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(Double(index) * 0.07)) { appeared = true }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { zoom = true }
            }
    }

    private var card: some View {
        ZStack(alignment: .bottom) {
            Image(theme.poster)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .scaleEffect(zoom ? 1.09 : 1.0)
                .clipped()

            LinearGradient(
                colors: [theme.surface.opacity(0.05), theme.surface.opacity(0.55), theme.surface.opacity(0.97)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [theme.accent.opacity(0.28), Color.clear], center: .topTrailing, startRadius: 10, endRadius: 280)

            Shimmer(color: theme.accent)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Spacer()
                    priceChip
                }
                Spacer(minLength: 0)
                Text(def.name)
                    .font(Theme.hero(28))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, theme.accent], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: theme.accent.opacity(0.6), radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(theme.subtitle)
                    .font(Theme.accent(13))
                    .foregroundColor(Color.white.opacity(0.78))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    PrizeImage(name: theme.mainPrize, days: 1, size: 28)
                    Text("Главный приз: \(theme.mainPrize)")
                        .font(Theme.title(12))
                        .foregroundColor(theme.accent)
                }
                .padding(.top, 2)
                HStack(spacing: 10) {
                    Button(action: onOpen) {
                        Text(openTitle)
                            .font(Theme.title(15))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .liquidGlass(Capsule(), tint: theme.accent.opacity(0.42), interactive: true)
                    }
                    .buttonStyle(.plain)

                    Button(action: onPeek) {
                        Image(systemName: "eye")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.9))
                            .frame(width: 50, height: 48)
                            .liquidGlass(Capsule(), tint: Color.black.opacity(0.25), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [theme.accent.opacity(0.85), theme.accent.opacity(0.06), theme.accent.opacity(0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: theme.accent.opacity(0.32), radius: 24, y: 12)
    }

    private var openTitle: String {
        if isFree { return freeLabel == nil ? "Получить дань" : "Через \(freeLabel!)" }
        return "Открыть кейс"
    }

    private var priceChip: some View {
        Text(isFree ? "БЕСПЛАТНО" : "\(Int(def.price)) ₽")
            .font(Theme.title(13))
            .tracking(isFree ? 2 : 0)
            .foregroundColor(isFree ? Color(hex: 0x04130D) : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isFree ? AnyShapeStyle(Theme.jade) : AnyShapeStyle(Color.black.opacity(0.0)), in: Capsule())
            .liquidGlass(Capsule(), tint: isFree ? nil : Color.black.opacity(0.35))
    }
}

// MARK: - Шансы

struct ChancesSheet: View {
    let def: CaseDef
    @State private var appeared = false

    var body: some View {
        let theme = CaseThemes.theme(def.id)
        let sorted = def.prizes.sorted { $0.rarity.sortRank < $1.rarity.sortRank }

        ZStack {
            LinearGradient(colors: [theme.deep, theme.surface, Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        Image(theme.poster)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipped()
                        LinearGradient(colors: [Color.clear, theme.surface.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(def.name)
                                .font(Theme.hero(26))
                                .foregroundStyle(LinearGradient(colors: [Color.white, theme.accent], startPoint: .top, endPoint: .bottom))
                            Text(theme.subtitle)
                                .font(Theme.accent(12))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                        .padding(16)
                    }
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(sorted) { prize in
                                VStack(spacing: 4) {
                                    PrizeImage(name: prize.name, days: prize.days, size: 54)
                                    Text(shortLabel(prize))
                                        .font(Theme.title(11))
                                        .foregroundColor(prize.rarity.color)
                                }
                                .padding(10)
                                .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: prize.rarity.color.opacity(0.16))
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { i, prize in
                            HStack(spacing: 12) {
                                PrizeImage(name: prize.name, days: prize.days, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prize.name)
                                        .font(Theme.title(15))
                                        .foregroundColor(Theme.text)
                                    Text(prize.rarity.label)
                                        .font(Theme.body(11))
                                        .foregroundColor(prize.rarity.color)
                                }
                                Spacer()
                                Text(prize.chanceText)
                                    .font(Theme.digits(17))
                                    .foregroundColor(Theme.goldLight)
                            }
                            .padding(12)
                            .liquidGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), tint: prize.rarity.color.opacity(0.10))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 18)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(i) * 0.045), value: appeared)
                        }
                    }

                    Text("Все шансы официальные и открытые.")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.muted)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { appeared = true }
    }

    private func shortLabel(_ p: Prize) -> String {
        if p.days == 730 { return "∞" }
        if p.days == -1 { return "🔄" }
        if p.days == 0 { return p.name.contains("год") ? "1 год" : "приз" }
        if p.days >= 365 { return "\(Int((Double(p.days) / 365).rounded())) г" }
        if p.days >= 30 { return "\(Int((Double(p.days) / 30).rounded())) мес" }
        return "\(p.days) д"
    }
}

// MARK: - Пополнение

struct TopUpSheet: View {
    @EnvironmentObject var site: SiteSession
    @Environment(\.dismiss) private var dismiss
    var need: Double?

    @State private var amount = 300
    @State private var custom = ""
    @State private var busy = false
    @State private var error: String?
    @State private var payLink: PayLink?
    @State private var waiting = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1408), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Пополнение баланса")
                    .font(Theme.hero(24))
                    .foregroundStyle(Theme.goldGradient)
                    .padding(.top, 26)
                Text(needText)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    ForEach([100, 300, 500, 1000], id: \.self) { value in
                        Button {
                            amount = value
                            custom = ""
                            Haptics.tick(fast: true)
                        } label: {
                            Text("\(value)₽")
                                .font(Theme.title(16))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .liquidGlass(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous),
                                    tint: (custom.isEmpty && amount == value) ? Theme.gold.opacity(0.35) : Color.black.opacity(0.2),
                                    interactive: true
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Другая сумма, от 100 ₽", text: $custom)
                    .keyboardType(.numberPad)
                    .font(Theme.body(16))
                    .foregroundColor(Theme.text)
                    .padding(14)
                    .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: Color.black.opacity(0.2))

                if let error {
                    Text(error).font(Theme.body(13)).foregroundColor(Theme.crimson)
                }

                Button {
                    Task { await start() }
                } label: {
                    HStack(spacing: 8) {
                        if busy || waiting { ProgressView().tint(Theme.text) }
                        Text(waiting ? "Ожидаю оплату…" : "Пополнить через ЮKassa")
                    }
                    .font(Theme.title(16))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.4), interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(busy || waiting)

                Text("Минимум 100 ₽. Деньги можно тратить на VPN и кейсы, ничего не сгорает.")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: $payLink) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .onDisappear { pollTask?.cancel() }
    }

    private var needText: String {
        if let need, need > 0 { return "Не хватает \(Int(need.rounded(.up))) ₽. Пополни баланс и открой кейс." }
        return "Выбери сумму и оплати картой."
    }

    private func start() async {
        error = nil
        let value = Int(custom) ?? amount
        guard value >= 100 else { error = "Минимум 100₽"; return }
        busy = true
        defer { busy = false }
        do {
            let d = try await SiteAPI.shared.jsonOK("/api/balance/topup", method: "POST", body: ["amount": value])
            guard let url = URL(string: jStr(d["url"])) else { throw APIError("Сервер не вернул ссылку на оплату") }
            let pid = jStr(d["payment_id"])
            waiting = true
            payLink = PayLink(url: url)
            poll(pid)
        } catch {
            self.error = error.localizedDescription
            SoundEngine.shared.play(.error)
        }
    }

    private func poll(_ pid: String) {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            for _ in 0..<150 {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { return }
                if let r = try? await SiteAPI.shared.json("/api/balance/topup/\(pid)"), jStr(r.obj["status"]) == "succeeded" {
                    site.balance = jNum(r.obj["balance"])
                    payLink = nil
                    waiting = false
                    SoundEngine.shared.play(.coin)
                    Haptics.success()
                    await site.refresh()
                    dismiss()
                    return
                }
            }
            waiting = false
        }
    }
}

// MARK: - Выдача призов вручную

struct ManualRewardSheet: View {
    let reward: ManualReward
    @EnvironmentObject var site: SiteSession
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var service = ""
    @State private var busy = false
    @State private var note = ""
    @State private var sent = false

    private var isMusic: Bool { reward.kind == "music" }
    private var artName: String {
        if isMusic { return "Музыка" }
        return reward.months >= 12 ? "Telegram Premium 1 год" : "Telegram Premium 1 месяц"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1408), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                PrizeImage(name: artName, days: 0, size: 120)
                    .shadow(color: Theme.gold.opacity(0.5), radius: 24)
                    .padding(.top, 28)
                Text(reward.prizeName.isEmpty ? "Ваш приз" : reward.prizeName)
                    .font(Theme.hero(24))
                    .foregroundStyle(Theme.goldGradient)
                    .multilineTextAlignment(.center)
                Text(isMusic
                     ? "Выбери музыкальный сервис. Подписка будет выдана вручную в течение 24 часов."
                     : "Telegram Premium будет отправлен подарком на указанный username в течение 24 часов.")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)

                if isMusic {
                    HStack(spacing: 10) {
                        serviceChip("VK Музыка", "vk")
                        serviceChip("Яндекс Музыка", "yandex")
                    }
                }

                TextField("@username в Telegram", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.body(16))
                    .foregroundColor(Theme.text)
                    .padding(14)
                    .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: Color.black.opacity(0.2))

                if !note.isEmpty {
                    Text(note).font(Theme.body(13)).foregroundColor(sent ? Theme.jade : Theme.crimson)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text(sent ? "Заявка отправлена" : "Подтвердить получение")
                        .font(Theme.title(16))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.4), interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(busy || sent)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.large])
        .onAppear {
            service = reward.service
            if !reward.username.isEmpty {
                username = "@" + reward.username.replacingOccurrences(of: "@", with: "")
            } else if !site.tgUsername.isEmpty {
                username = "@" + site.tgUsername
            }
        }
    }

    private func serviceChip(_ title: String, _ value: String) -> some View {
        Button {
            service = value
            Haptics.tick(fast: true)
        } label: {
            Text(title)
                .font(Theme.title(14))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .liquidGlass(RoundedRectangle(cornerRadius: 16, style: .continuous),
                             tint: service == value ? Theme.gold.opacity(0.4) : Color.black.opacity(0.2), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func submit() async {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { note = "Введи Telegram username"; return }
        if isMusic && service.isEmpty { note = "Выбери музыкальный сервис"; return }
        busy = true
        defer { busy = false }
        do {
            _ = try await SiteAPI.shared.jsonOK(
                "/api/cases/manual-reward/submit", method: "POST",
                body: ["claim_token": reward.claimToken, "username": name, "service": service]
            )
            sent = true
            note = "Заявка принята. Выдача будет выполнена в течение 24 часов."
            SoundEngine.shared.play(.coin)
            Haptics.success()
        } catch {
            note = error.localizedDescription
            SoundEngine.shared.play(.error)
        }
    }
}

struct PremiumClaimSheet: View {
    @EnvironmentObject var site: SiteSession
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var sent = false
    @State private var note = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1408), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 16) {
                PrizeImage(name: "Telegram Premium", days: 0, size: 120)
                    .shadow(color: Theme.gold.opacity(0.5), radius: 24)
                    .padding(.top, 28)
                Text("Вы выиграли Telegram Premium!")
                    .font(Theme.hero(22))
                    .foregroundStyle(Theme.goldGradient)
                    .multilineTextAlignment(.center)
                Text("Premium будет выдан в течение 24 часов. Администратор свяжется с вами.")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)

                if site.telegramLinked {
                    Text("Ваш Telegram привязан, мы знаем куда отправить Premium. Ожидайте в течение 24 часов.")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.jade)
                        .multilineTextAlignment(.center)
                    Button("Отлично, жду!") { dismiss() }
                        .font(Theme.title(16))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.4), interactive: true)
                } else {
                    TextField("@username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(Theme.body(16))
                        .foregroundColor(Theme.text)
                        .padding(14)
                        .liquidGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: Color.black.opacity(0.2))
                    if !note.isEmpty { Text(note).font(Theme.body(13)).foregroundColor(sent ? Theme.jade : Theme.crimson) }
                    Button {
                        Task { await send() }
                    } label: {
                        Text(sent ? "Отправлено" : "Отправить")
                            .font(Theme.title(16))
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.4), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(sent)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.large])
    }

    private func send() async {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { note = "Введи username"; return }
        if let r = try? await SiteAPI.shared.json("/api/cases/premium-claim", method: "POST", body: ["username": name]),
           jStr(r.obj["status"]) == "ok" {
            sent = true
            note = "Заявка отправлена! Ожидайте в течение 24 часов."
            SoundEngine.shared.play(.coin)
            Haptics.success()
        } else {
            note = "Не удалось отправить, попробуй ещё раз"
            SoundEngine.shared.play(.error)
        }
    }
}

// MARK: - Братство

struct BrotherhoodView: View {
    @EnvironmentObject var site: SiteSession
    @ObservedObject var store: CasesStore
    let onOpenCase: (String) -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "БРАТСТВО")

            VStack(alignment: .leading, spacing: 14) {
                Text("Приведи брата в семью и получи бесплатный кейс. Каждый пятый брат приносит Top G кейс.")
                    .font(Theme.body(14))
                    .foregroundColor(Theme.text.opacity(0.85))

                if let ref = store.referral, ref.exists {
                    HStack {
                        Text(ref.url)
                            .font(Theme.body(12))
                            .foregroundColor(Theme.goldLight)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = ref.url
                            copied = true
                            Haptics.success()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Label(copied ? "Скопировано" : "Привести брата", systemImage: copied ? "checkmark" : "person.2.fill")
                                .font(Theme.title(14))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .liquidGlass(Capsule(), tint: Theme.gold.opacity(0.35), interactive: true)
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: ref.url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17))
                                .foregroundColor(Theme.text)
                                .frame(width: 50, height: 46)
                                .liquidGlass(Capsule(), tint: Color.black.opacity(0.25), interactive: true)
                        }
                    }

                    HStack(spacing: 10) {
                        stat("Братьев привёл", "\(ref.count)")
                        stat("Доступно кейсов", "\(ref.casesG + ref.casesTopG)")
                    }
                    Text("До Top G кейса: \(ref.nextTopG) братьев")
                        .font(Theme.body(12))
                        .foregroundColor(Theme.muted)

                    if ref.casesG > 0 {
                        giftRow("Кейс G", "\(ref.casesG)", "g")
                    }
                    if ref.casesTopG > 0 {
                        giftRow("Кейс Top G", "\(ref.casesTopG)", "topg")
                    }
                } else if !site.isLoggedIn {
                    Text("Войди через Telegram, чтобы получить свою ссылку.")
                        .font(Theme.body(13))
                        .foregroundColor(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("КАК ЭТО РАБОТАЕТ")
                        .font(Theme.label(11))
                        .tracking(3)
                        .foregroundColor(Theme.goldDim)
                    step("1", "Нажми «Привести брата», скопируется твоя ссылка")
                    step("2", "Брат переходит по ней и оплачивает первый месяц VPN")
                    step("3", "Тебе автоматически приходит бесплатный G кейс")
                    step("4", "Каждый 5-й брат приносит Top G кейс")
                }
            }
            .padding(16)
            .liquidGlass(RoundedRectangle(cornerRadius: 26, style: .continuous), tint: Color.black.opacity(0.22))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.digits(26)).foregroundStyle(Theme.goldGradient)
            Text(title).font(Theme.body(11)).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func giftRow(_ title: String, _ count: String, _ id: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(15)).foregroundColor(Theme.text)
                Text("Бесплатно · \(count) шт").font(Theme.body(12)).foregroundColor(Theme.muted)
            }
            Spacer()
            Button {
                onOpenCase(id)
            } label: {
                Text("Открыть")
                    .font(Theme.title(14))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .liquidGlass(Capsule(), tint: Theme.jade.opacity(0.4), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n).font(Theme.digits(13)).foregroundColor(Theme.gold).frame(width: 14)
            Text(text).font(Theme.body(13)).foregroundColor(Theme.text.opacity(0.8))
        }
    }
}
