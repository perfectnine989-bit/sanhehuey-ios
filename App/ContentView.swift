import NetworkExtension
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpn: VPNManager
    @State private var tab: AppTab = .home

    private var palette: Palette { Palette.forStatus(vpn.status) }

    var body: some View {
        ZStack {
            SceneBackground(palette: palette, isOn: vpn.isOn)

            VStack(spacing: 0) {
                HeaderView(palette: palette)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Group {
                    switch tab {
                    case .home:
                        HomeScreen(palette: palette).transition(.opacity)
                    case .profile:
                        ProfileScreen(palette: palette).transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeOut(duration: 0.18), value: tab)

                GlassTabBar(selection: $tab, palette: palette)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct HomeScreen: View {
    @EnvironmentObject var vpn: VPNManager
    let palette: Palette

    private var statusColor: Color {
        switch vpn.status {
        case .connected: return Theme.jade
        case .connecting, .reasserting, .disconnecting: return Color(hex: 0xFFC25A)
        default: return Theme.text
        }
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            PowerButton(palette: palette)

            VStack(spacing: 5) {
                Text(vpn.statusText.uppercased())
                    .font(Theme.title(21))
                    .tracking(4)
                    .foregroundColor(statusColor)
                    .shadow(color: Color.black.opacity(0.9), radius: 6)

                NeonBanner(color: palette.glow, since: vpn.status == .connected && vpn.mode != .direct ? vpn.connectedDate : nil)

                if vpn.status == .connected, let since = vpn.connectedDate {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.format(context.date.timeIntervalSince(since)))
                            .font(Theme.digits(16))
                            .foregroundColor(Theme.goldLight)
                            .shadow(color: Color.black.opacity(0.9), radius: 5)
                    }
                } else {
                    Text("Нажми на кнопку, чтобы подключиться")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.muted)
                        .shadow(color: Color.black.opacity(0.9), radius: 5)
                }

                if let error = vpn.errorText {
                    Text(error)
                        .font(Theme.body(12))
                        .foregroundColor(Theme.crimson)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(minHeight: 84)

            Spacer(minLength: 8)

            SectionTitle(text: "РЕЖИМ РАБОТЫ")
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            ModePicker(palette: palette)
                .padding(.horizontal, 20)

            if vpn.mode == .direct {
                StrategyCard(palette: palette)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.opacity)
                WarpCard(palette: palette)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .transition(.opacity)
            }

            TrafficStrip(traffic: vpn.traffic, palette: palette, active: vpn.status == .connected)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
    }
}
