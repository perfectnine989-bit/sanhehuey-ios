import SwiftUI

enum EntryStore {
    static var current: ServerEntry {
        get { ServerEntry(rawValue: UserDefaults.standard.string(forKey: "server.entry") ?? "") ?? .reality }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "server.entry") }
    }
}

/// Переключатель входа на сервер. Показывается только в режимах «Умный» и «Весь трафик».
struct EntryCard: View {
    @EnvironmentObject var vpn: VPNManager
    @State private var entry = EntryStore.current
    let palette: Palette

    private func select(_ item: ServerEntry) {
        guard item != entry else { return }
        EntryStore.current = item
        entry = item
        if vpn.isOn { Task { _ = await vpn.restartAndWait() } }
    }

    var body: some View {
        Menu {
            ForEach(ServerEntry.allCases, id: \.self) { item in
                Button(item.title) { select(item) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 15))
                    .foregroundColor(palette.light)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ВХОД НА СЕРВЕР")
                        .font(Theme.label(11))
                        .tracking(2)
                        .foregroundColor(Theme.goldDim)
                    Text(entry.title)
                        .font(Theme.body(15))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
            }
            .padding(14)
            .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Color.black.opacity(0.22))
        }
    }
}
