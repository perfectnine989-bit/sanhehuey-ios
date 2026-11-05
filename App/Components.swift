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
        HStack {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.goldDim.opacity(0.7), lineWidth: 1))
                .padding(5)
                .liquidGlass(Circle())
                .frame(width: 104, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    Text("СанХэХуэй")
                        .font(Theme.accent(28))
                        .foregroundStyle(Theme.goldGradient)
                    Text("VPN")
                        .font(Theme.accent(28))
                        .foregroundColor(palette.main)
                }
                HStack(spacing: 8) {
                    Rectangle().fill(Theme.goldDim.opacity(0.5)).frame(width: 26, height: 1)
                    Text("三和会")
                        .font(Theme.accent(13))
                        .tracking(5)
                        .foregroundColor(Theme.goldDim)
                    Rectangle().fill(Theme.goldDim.opacity(0.5)).frame(width: 26, height: 1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Circle()
                    .fill(palette.glow)
                    .frame(width: 8, height: 8)
                    .shadow(color: palette.glow, radius: 5)
                Text("Hysteria2")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .liquidGlass(Capsule())
            .frame(width: 104, alignment: .trailing)
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.goldDim.opacity(0.45)).frame(height: 1)
            Text(text)
                .font(Theme.body(12))
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
                    .font(Theme.body(10))
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
        .liquidGlass(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.45), in: Capsule())
        .overlay(Capsule().stroke(Theme.goldDim.opacity(0.35), lineWidth: 1))
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return VStack(spacing: 4) {
            Image(systemName: tab.icon)
                .font(.system(size: 19))
            Text(tab.title)
                .font(Theme.body(11))
        }
        .foregroundColor(selected ? palette.light : Theme.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            if selected {
                Capsule()
                    .fill(Color.clear)
                    .liquidGlass(Capsule(), tint: palette.main.opacity(0.35), interactive: true)
                    .matchedGeometryEffect(id: "tab", in: ns)
            }
        }
        .contentShape(Capsule())
        .onTapGesture {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                selection = tab
            }
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
                    .font(Theme.accent(24))
                    .foregroundColor(Theme.text)
                Text(text)
                    .font(Theme.body(14))
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
