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
                        HomeScreen(palette: palette)
                    case .servers:
                        ComingSoon(title: "Серверы", icon: "server.rack", text: "Выбор локаций появится здесь")
                    case .profile:
                        ComingSoon(title: "Профиль", icon: "person.crop.circle", text: "Подписка и ключи появятся здесь")
                    }
                }
                .frame(maxHeight: .infinity)

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

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            PowerButton(palette: palette)

            VStack(spacing: 5) {
                Text(vpn.statusText.uppercased())
                    .font(Theme.title(20))
                    .tracking(4)
                    .foregroundColor(statusColor)
                    .shadow(color: Color.black.opacity(0.9), radius: 6)

                NeonBanner(color: palette.glow, since: vpn.status == .connected ? vpn.connectedDate : nil)

                if vpn.status != .connected {
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

            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    InfoTile(title: "ПРОТОКОЛ", value: "Hysteria2", icon: "bolt.horizontal.fill", accent: palette.light)
                    InfoTile(title: "МАСКА", value: "Salamander", icon: "eye.slash.fill", accent: palette.light)
                    SessionTile(accent: palette.light)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }
}
