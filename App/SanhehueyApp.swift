import SwiftUI

@main
struct SanhehueyApp: App {
    @StateObject private var vpn = VPNManager()
    @StateObject private var site = SiteSession()
    @Environment(\.scenePhase) private var scenePhase

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
                        site.resumeLoginCheck()
                        if vpn.mode != .direct { Task { await site.refresh() } }
                    }
                }
        }
    }
}
