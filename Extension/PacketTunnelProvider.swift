import Foundation
import Libbox
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var service: LibboxBoxService?
    private var platform: PlatformInterface?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let raw = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["mode"] as? String
        let mode = RouteMode(rawValue: raw ?? "") ?? .smart

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                try start(mode: mode)
                completionHandler(nil)
            } catch {
                NSLog("[Sanhehuey] start failed: \(error.localizedDescription)")
                completionHandler(error)
            }
        }
    }

    private func start(mode: RouteMode) throws {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let working = base.appendingPathComponent("working", isDirectory: true)
        let temp = base.appendingPathComponent("tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let setup = LibboxSetupOptions()
        setup.basePath = base.path
        setup.workingPath = working.path
        setup.tempPath = temp.path
        var error: NSError?
        LibboxSetup(setup, &error)
        if let error { throw error }

        // Ограничение памяти нужно, иначе iOS убьёт расширение (лимит ~50 МБ).
        LibboxSetMemoryLimit(true)

        let platform = PlatformInterface(self)
        self.platform = platform

        let serverIP = ServerResolver.resolve(Credentials.server)
        NSLog("[Sanhehuey] server \(Credentials.server) -> \(serverIP)")
        let config = SingConfig.build(mode: mode, server: serverIP)
        let service = LibboxNewService(config, platform, &error)
        if let error { throw error }
        guard let service else {
            throw NSError(domain: "Sanhehuey", code: 1, userInfo: [NSLocalizedDescriptionKey: "service is nil"])
        }
        try service.start()
        self.service = service
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            try? service?.close()
            service = nil
            platform?.reset()
            platform = nil
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }
}
