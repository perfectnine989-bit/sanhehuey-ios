import Lottie
import SwiftUI

struct LottieSlot: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let view = LottieAnimationView()
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        if let animation = try? LottieAnimation.from(data: data) {
            view.animation = animation
            view.play()
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Эмодзи-статус Telegram: анимированный (Lottie), картинка или текст, как на сайте.
struct EmojiStatusView: View {
    let status: EmojiStatus
    let size: CGFloat
    @State private var lottieData: Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if status.kind == "lottie", let data = lottieData {
                LottieSlot(data: data)
            } else if status.kind == "image", let image {
                Image(uiImage: image)
                    .renderingMode(status.repaint ? .template : .original)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Theme.gold)
            } else {
                Text(status.alt.isEmpty ? "✦" : status.alt)
                    .font(.system(size: size * 0.8))
            }
        }
        .frame(width: size, height: size)
        .task(id: (status.lottieURL?.absoluteString ?? "") + (status.mediaURL?.absoluteString ?? "")) { await load() }
    }

    private func load() async {
        if status.kind == "lottie", let url = status.lottieURL,
           let (data, _) = try? await URLSession.shared.data(from: url) {
            lottieData = data
        } else if status.kind == "image", let url = status.mediaURL,
                  let (data, _) = try? await URLSession.shared.data(from: url) {
            image = UIImage(data: data)
        }
    }
}

struct ProfileScreen: View {
    @EnvironmentObject var vpn: VPNManager
    @EnvironmentObject var site: SiteSession
    @ObservedObject private var stats = StatsStore.shared
    let palette: Palette

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var sinceText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter.string(from: stats.firstLaunch)
    }

    private func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours) ч \(minutes % 60) м" : "\(minutes) мин"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                identity
                if site.isLoggedIn {
                    accountCard
                    if let loyalty = site.loyalty { loyaltyCard(loyalty) }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    statTile(duration(stats.totalSeconds), "ПОД ЗАЩИТОЙ", "shield.lefthalf.filled")
                    statTile("\(stats.sessions)", "СЕССИЙ", "bolt.fill")
                    statTile(ByteCountFormatter.string(fromByteCount: Int64(stats.totalBytes), countStyle: .file), "ТРАФИК", "arrow.up.arrow.down")
                    statTile("\(stats.streak) дн", "СЕРИЯ ДНЕЙ", "flame.fill")
                }

                infoCard(title: "СОЕДИНЕНИЕ", rows: [
                    ("Протокол", "Hysteria2"),
                    ("Маскировка", "Salamander · UDP 443"),
                    ("Режим", vpn.mode.title),
                    ("Статус", vpn.statusText)
                ])
                infoCard(title: "ПРИЛОЖЕНИЕ", rows: [("Версия", appVersion), ("С нами с", sinceText)])

                if site.isLoggedIn {
                    Button {
                        Task { await site.logout() }
                    } label: {
                        Text("Выйти из аккаунта")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.muted)
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .refreshable { await site.refresh() }
    }

    // MARK: личность

    private var identity: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatar = site.avatar {
                        Image(uiImage: avatar).resizable().scaledToFill()
                    } else {
                        Image("avatar").resizable().scaledToFill()
                    }
                }
                .frame(width: 108, height: 108)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.goldGradient, lineWidth: 2.5))
                .shadow(color: palette.glow.opacity(0.55), radius: 18)

                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldGradient)
                    .padding(8)
                    .liquidGlass(Circle(), tint: Color.black.opacity(0.3))
                    .offset(x: 4, y: 4)
            }

            if site.isLoggedIn {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(site.displayName)
                            .font(Theme.hero(28))
                            .foregroundStyle(Theme.goldGradient)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if let emoji = site.emoji {
                            EmojiStatusView(status: emoji, size: 28)
                        }
                    }
                    if !site.tgUsername.isEmpty {
                        Text("@" + site.tgUsername)
                            .font(Theme.body(14))
                            .foregroundColor(Theme.muted)
                    }
                    if let loyalty = site.loyalty {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(palette.light)
                            Text(loyalty.title).font(Theme.title(13)).foregroundColor(Theme.text)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .liquidGlass(Capsule())
                    }
                }
                if !site.telegramLinked {
                    LoginButton(link: true).padding(.horizontal, 12)
                }
            } else {
                VStack(spacing: 6) {
                    Text("BossTriad")
                        .font(Theme.hero(28))
                        .foregroundStyle(Theme.goldGradient)
                    Text("Войди через Telegram, и здесь появятся твоя аватарка, статус и баланс.")
                        .font(Theme.body(13))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                LoginButton().padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .liquidGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: Color.black.opacity(0.22))
    }

    // MARK: аккаунт и уровень

    private var accountCard: some View {
        var rows: [(String, String)] = [("Баланс", "\(Int(site.balance.rounded())) ₽")]
        let expires = jStr(site.user["expires_at"])
        let days = jInt(site.user["days_left"])
        if !expires.isEmpty {
            rows.append(("Подписка до", days > 3000 || expires.hasPrefix("01.01.2099") ? "Бессрочно" : expires))
            if days > 0 && days <= 3000 { rows.append(("Осталось", "\(days) дн.")) }
        } else {
            rows.append(("Подписка", jBool(site.user["active"]) ? "Активна" : "Нет"))
        }
        if site.telegramLinked && !site.tgUsername.isEmpty { rows.append(("Telegram", "@" + site.tgUsername)) }
        return infoCard(title: "АККАУНТ", rows: rows)
    }

    private func loyaltyCard(_ l: Loyalty) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СТАТУС СЕМЬИ")
                .font(Theme.label(12))
                .tracking(4)
                .foregroundColor(Theme.goldDim)
            HStack {
                Text(l.title).font(Theme.hero(22)).foregroundStyle(Theme.goldGradient)
                Spacer()
                Text("\(Int(l.totalSpent)) ₽").font(Theme.digits(18)).foregroundColor(Theme.goldLight)
            }
            HStack(spacing: 6) {
                ForEach(Array(l.tiers.enumerated()), id: \.offset) { _, tier in
                    let done = l.totalSpent >= tier.threshold
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(done ? Theme.jade : Color.white.opacity(0.12))
                            .frame(height: 5)
                        Text("\(Int(tier.threshold))₽")
                            .font(Theme.body(10))
                            .foregroundColor(done ? Theme.jade : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let next = l.nextTitle, !next.isEmpty {
                Text("До «\(next)» осталось пополнить на \(Int(l.toNext)) ₽")
                    .font(Theme.body(13))
                    .foregroundColor(Theme.muted)
            } else {
                Text("Максимальный уровень")
                    .font(Theme.title(13))
                    .foregroundColor(Theme.jade)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: Color.black.opacity(0.22))
    }

    private func statTile(_ value: String, _ title: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(palette.light)
                Text(title).font(Theme.label(11)).tracking(2).foregroundColor(Theme.goldDim)
            }
            Text(value)
                .font(Theme.digits(24))
                .foregroundColor(Theme.goldLight)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Color.black.opacity(0.22))
    }

    private func infoCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.label(12)).tracking(4).foregroundColor(Theme.goldDim)
            ForEach(0..<rows.count, id: \.self) { i in
                HStack {
                    Text(rows[i].0).font(Theme.body(15)).foregroundColor(Theme.muted)
                    Spacer()
                    Text(rows[i].1).font(Theme.body(15)).foregroundColor(Theme.text).multilineTextAlignment(.trailing)
                }
                if i < rows.count - 1 {
                    Rectangle().fill(Theme.goldDim.opacity(0.18)).frame(height: 1)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: Color.black.opacity(0.22))
    }
}
