import SwiftUI

enum AppTab: String, CaseIterable {
    case home, cases, profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .cases: return "Кейсы"
        case .profile: return "Профиль"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .cases: return "briefcase.fill"
        case .profile: return "person.fill"
        }
    }
}

struct HeaderView: View {
    let palette: Palette

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("SanHeHuey")
                    .font(Theme.hero(34))
                    .foregroundStyle(Theme.goldGradient)
                Text("VPN")
                    .font(Theme.title(17))
                    .tracking(2)
                    .foregroundColor(palette.main)
                    .shadow(color: palette.glow.opacity(0.7), radius: 8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            HStack(spacing: 10) {
                Rectangle().fill(Theme.goldDim.opacity(0.5)).frame(width: 34, height: 1)
                Text("三和会")
                    .font(.system(size: 13, weight: .regular, design: .serif))
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
                .font(Theme.neon(18))
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
            Rectangle().fill(Theme.goldDim.opacity(0.4)).frame(height: 1)
            Text(text)
                .font(Theme.label(12))
                .tracking(5)
                .foregroundColor(Theme.goldDim)
                .fixedSize()
            Rectangle().fill(Theme.goldDim.opacity(0.4)).frame(height: 1)
        }
    }
}

/// Реальная скорость и пинг, как в концепте.
struct TrafficStrip: View {
    @ObservedObject var traffic: TrafficMonitor
    let palette: Palette
    let active: Bool

    private func speed(_ value: Double) -> String {
        guard active else { return "—" }
        return value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(icon: "arrow.down", value: speed(traffic.down), unit: "Мбит/с")
            divider
            stat(icon: "arrow.up", value: speed(traffic.up), unit: "Мбит/с")
            divider
            stat(icon: "speedometer", value: (active ? traffic.pingMs.map { "\($0)" } : nil) ?? "—", unit: "мс")
        }
        .padding(.vertical, 13)
        .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Color.black.opacity(0.22))
    }

    private var divider: some View {
        Rectangle().fill(Theme.goldDim.opacity(0.25)).frame(width: 1, height: 22)
    }

    private func stat(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(palette.light)
            Text(value)
                .font(Theme.digits(20))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(Theme.body(11))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppTab
    let palette: Palette

    var body: some View {
        GlassSegmented(
            items: AppTab.allCases,
            selection: $selection,
            tint: palette.main.opacity(0.14),
            height: 52,
            corner: 26
        ) { tab, isSelected in
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17))
                Text(tab.title)
                    .font(Theme.label(12))
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
