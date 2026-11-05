import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var vpn: VPNManager
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
                hero

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

                infoCard(title: "ПРИЛОЖЕНИЕ", rows: [
                    ("Версия", appVersion),
                    ("С нами с", sinceText)
                ])
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image("avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 104)
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

            VStack(spacing: 5) {
                Text("BossTriad")
                    .font(Theme.hero(30))
                    .foregroundStyle(Theme.goldGradient)
                HStack(spacing: 8) {
                    Text("龙头")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(Theme.goldDim)
                    Text("·")
                        .foregroundColor(Theme.goldDim)
                    Text("ГОЛОВА ДРАКОНА")
                        .font(Theme.title(13))
                        .tracking(3)
                        .foregroundColor(Theme.goldDim)
                }
            }

            HStack(spacing: 8) {
                chip("Основатель", "star.fill")
                chip("Босс", "flame.fill")
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .liquidGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: Color.black.opacity(0.22))
    }

    private func chip(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(palette.light)
            Text(text)
                .font(Theme.body(13))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .liquidGlass(Capsule())
    }

    private func statTile(_ value: String, _ title: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(palette.light)
                Text(title)
                    .font(Theme.label(11))
                    .tracking(2)
                    .foregroundColor(Theme.goldDim)
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
            Text(title)
                .font(Theme.label(12))
                .tracking(4)
                .foregroundColor(Theme.goldDim)
            ForEach(0..<rows.count, id: \.self) { i in
                HStack {
                    Text(rows[i].0)
                        .font(Theme.body(15))
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Text(rows[i].1)
                        .font(Theme.body(15))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.trailing)
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
