import SwiftUI
import NetworkExtension

struct ContentView: View {
    @EnvironmentObject var vpn: VPNManager
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Дракон на фоне
            Image("dragon")
                .resizable()
                .scaledToFill()
                .opacity(vpn.isOn ? 0.22 : 0.10)
                .blur(radius: 1)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: vpn.isOn)

            Image("smoke")
                .resizable()
                .scaledToFill()
                .opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            LinearGradient(
                colors: [Theme.bg.opacity(0.85), .clear, Theme.bg.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                powerButton
                statusBlock
                Spacer(minLength: 12)
                modeCard
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 22)
        }
        .onAppear { pulse = true }
    }

    // MARK: Шапка

    private var header: some View {
        VStack(spacing: 6) {
            Text("СанХэХуэй")
                .font(Theme.title(30))
                .foregroundColor(Theme.goldLight)
                .tracking(2)
            Text("三和会")
                .font(Theme.accent(16))
                .foregroundColor(Theme.goldDim)
                .tracking(6)
        }
        .padding(.top, 18)
    }

    // MARK: Кнопка

    private var powerButton: some View {
        Button(action: { vpn.toggle() }) {
            ZStack {
                Image("glow_on")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 340, height: 340)
                    .opacity(vpn.isOn ? (pulse ? 0.95 : 0.55) : 0)
                    .animation(vpn.isOn ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default, value: pulse)
                    .animation(.easeInOut(duration: 0.6), value: vpn.isOn)

                Image(vpn.isOn ? "ember_on" : "ember_off")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .scaleEffect(vpn.status == .connecting ? 0.94 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: vpn.status)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Theme.gold.opacity(0.0), Theme.goldLight, Theme.gold.opacity(0.0)],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 214, height: 214)
                    .opacity(vpn.isOn ? 0.9 : 0.25)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                    .animation(.linear(duration: 9).repeatForever(autoreverses: false), value: pulse)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 340)
    }

    // MARK: Статус

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(vpn.statusText.uppercased())
                .font(Theme.title(20))
                .foregroundColor(vpn.status == .connected ? Theme.jade : Theme.text)
                .tracking(3)
                .animation(.easeInOut, value: vpn.status)

            if vpn.status == .connected, let since = vpn.connectedDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.format(context.date.timeIntervalSince(since)))
                        .font(Theme.body(22))
                        .foregroundColor(Theme.goldLight)
                        .monospacedDigit()
                }
            } else {
                Text("Нажми на уголёк")
                    .font(Theme.accent(15))
                    .foregroundColor(Theme.muted)
            }

            if let error = vpn.errorText {
                Text(error)
                    .font(Theme.body(12))
                    .foregroundColor(Theme.crimson)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(minHeight: 90)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // MARK: Выбор режима

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("РЕЖИМ")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.goldDim)
                    .tracking(3)
                Spacer()
                Text("Hysteria2")
                    .font(Theme.body(12))
                    .foregroundColor(Theme.muted)
            }

            HStack(spacing: 10) {
                ForEach(RouteMode.allCases, id: \.self) { item in
                    Button(action: { vpn.setMode(item) }) {
                        Text(item.title)
                            .font(Theme.body(15))
                            .foregroundColor(vpn.mode == item ? Theme.bg : Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(vpn.mode == item ? Theme.gold : Theme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(vpn.mode == item ? Theme.goldLight : Theme.goldDim.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(vpn.mode.subtitle)
                .font(Theme.accent(14))
                .foregroundColor(Theme.muted)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.goldDim.opacity(0.4), lineWidth: 1)
        )
    }
}
