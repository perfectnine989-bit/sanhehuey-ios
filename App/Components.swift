import SwiftUI

enum AppTab: String, CaseIterable {
    case home, servers, profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .servers: return "Серверы"
        case .profile: return "Профиль"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .servers: return "server.rack"
        case .profile: return "person.fill"
        }
    }
}

struct HeaderView: View {
    let palette: Palette

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 9) {
                Text("СанХэХуэй")
                    .font(Theme.hero(30))
                    .foregroundStyle(Theme.goldGradient)
                Text("VPN")
                    .font(Theme.hero(30))
                    .foregroundColor(palette.main)
                    .shadow(color: palette.glow.opacity(0.7), radius: 8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 10) {
                Rectangle().fill(Theme.goldDim.opacity(0.5)).frame(width: 34, height: 1)
                Text("三和会")
                    .font(Theme.accent(14))
                    .tracking(6)
                    .foregroundColor(Theme.goldDim)
                Rectangle().fill(Theme.goldDim.opacity(0.5)).frame(width: 34, height: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// «Под защитой Триады»: выключенная неоновая трубка, которая вспыхивает при подключении.
struct NeonBanner: View {
    let color: Color
    let since: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            let level: Double = {
                guard let since else { return 0 }
                let age = timeline.date.timeIntervalSince(since)
                if age < 0 { return 0 }
                if age < 1.6 {
                    let steps: [Double] = [0, 0.9, 0.1, 1, 0.2, 0.15, 1, 0.5, 1, 1]
                    let idx = min(steps.count - 1, Int(age / 0.16))
                    return steps[idx]
                }
                return 0.93 + 0.07 * sin(timeline.date.timeIntervalSinceReferenceDate * 5)
            }()
            Text("ПОД ЗАЩИТОЙ ТРИАДЫ")
                .font(Theme.title(19))
                .tracking(3)
                .foregroundColor(Color.white.opacity(0.10 + 0.85 * level))
                .shadow(color: color.opacity(level), radius: 3)
                .shadow(color: color.opacity(level), radius: 10)
                .shadow(color: color.opacity(0.7 * level), radius: 22)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.goldDim.opacity(0.45)).frame(height: 1)
            Text(text)
                .font(Theme.label(14))
                .tracking(5)
                .foregroundColor(Theme.goldDim)
                .fixedSize()
            Rectangle().fill(Theme.goldDim.opacity(0.45)).frame(height: 1)
        }
    }
}

struct InfoTile: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(accent)
                Text(title)
                    .font(Theme.label(12))
                    .tracking(2)
                    .foregroundColor(Theme.goldDim)
            }
            Text(value)
                .font(Theme.body(17))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), tint: Color.black.opacity(0.28))
    }
}

struct SessionTile: View {
    @EnvironmentObject var vpn: VPNManager
    let accent: Color

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text: String = {
                if vpn.status == .connected, let since = vpn.connectedDate {
                    return Self.format(context.date.timeIntervalSince(since))
                }
                return "—"
            }()
            InfoTile(title: "СЕССИЯ", value: text, icon: "clock.fill", accent: accent)
        }
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppTab
    let palette: Palette

    var body: some View {
        GlassSegmented(
            items: AppTab.allCases,
            selection: $selection,
            tint: palette.main.opacity(0.35),
            height: 54,
            corner: 27
        ) { tab, isSelected in
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                Text(tab.title)
                    .font(Theme.label(13))
            }
            .foregroundColor(isSelected ? palette.light : Theme.muted)
        }
    }
}

struct ComingSoon: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.goldGradient)
                Text(title)
                    .font(Theme.title(24))
                    .foregroundColor(Theme.text)
                Text(text)
                    .font(Theme.body(15))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .liquidGlass(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}
