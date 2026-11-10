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
        let rawStrategy = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["strategy"] as? String
        let strategy = DPIStrategy(rawValue: rawStrategy ?? "") ?? .auto
        let customArgs = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["bdargs"] as? String ?? ""

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                try start(mode: mode, strategy: strategy, customArgs: customArgs)
                completionHandler(nil)
            } catch {
                NSLog("[Sanhehuey] start failed: \(error.localizedDescription)")
                completionHandler(error)
            }
        }
    }

    private func start(mode: RouteMode, strategy: DPIStrategy, customArgs: String) throws {
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

        let config: String
        if mode == .direct {
            // Режим «Без сервера»: сервер не трогаем совсем, даже адрес не ищем.
            NSLog("[Sanhehuey] direct mode, strategy \(strategy.rawValue)")
            if let args = strategy.engineArgs(custom: customArgs) {
                ByeDPIEngine.start(port: SingConfig.enginePort, strategyArgs: args)
            }
            config = SingConfig.buildDirect(strategy: strategy, customArgs: customArgs)
        } else {
            let serverIP = ServerResolver.resolve(Credentials.server)
            NSLog("[Sanhehuey] server \(Credentials.server) -> \(serverIP)")
            config = SingConfig.build(mode: mode, server: serverIP)
        }
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
            if ByeDPIEngine.isRunning {
                // Движок нельзя перезапустить в том же процессе: выходим, iOS поднимет расширение заново
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { exit(0) }
            }
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }
}
