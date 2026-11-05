import SwiftUI

@main
struct SanhehueyApp: App {
    @StateObject private var vpn = VPNManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpn)
                .preferredColorScheme(.dark)
        }
    }
}
