import SwiftUI

@main
struct SanhehueyApp: App {
    @StateObject private var vpn = VPNManager.shared
    @StateObject private var site = SiteSession()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Кнопка в Dynamic Island вызывает это, даже если приложение запущено в фоне
        IslandBridge.toggle = { await VPNManager.shared.toggleFromIsland() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpn)
                .environmentObject(site)
                .preferredColorScheme(.dark)
                // В режиме «Без сервера» сами к сайту не обращаемся (он на том же сервере).
                .task { if vpn.mode != .direct { await site.refresh() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Island.viaIsland = false
                        vpn.syncIsland()
                        site.resumeLoginCheck()
                        if vpn.mode != .direct { Task { await site.refresh() } }
                    }
                }
        }
    }
}
