import SwiftUI

/// Кнопка входа/привязки Telegram с состоянием ожидания.
struct LoginButton: View {
    @EnvironmentObject var site: SiteSession
    var link = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
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
