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
                .task { await site.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        site.resumeLoginCheck()
                        Task { await site.refresh() }
                    }
                }
        }
    }
}
