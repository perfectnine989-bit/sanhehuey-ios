import Foundation
import Libbox
import Network
import NetworkExtension

/// Мост между движком sing-box (Libbox) и iOS. Основан на официальном клиенте sing-box (GPL-3.0).
final class PlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private unowned let tunnel: NEPacketTunnelProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: NWPathMonitor?

    init(_ tunnel: NEPacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        networkSettings = nil
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    // MARK: - TUN

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options else { throw NSError(domain: "nil options", code: 0) }
        guard let ret0_ else { throw NSError(domain: "nil return pointer", code: 0) }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            let dnsServer = try options.getDNSServerAddress()
            let dnsSettings = NEDNSSettings(servers: [dnsServer.value])
            dnsSettings.matchDomains = [""]
            dnsSettings.matchDomainsNoSearch = true
            settings.dnsSettings = dnsSettings

            // IPv4
            var v4Address: [String] = []
            var v4Mask: [String] = []
            let v4It = options.getInet4Address()!
            while v4It.hasNext() {
                let p = v4It.next()!
                v4Address.append(p.address())
                v4Mask.append(p.mask())
            }
            let v4 = NEIPv4Settings(addresses: v4Address, subnetMasks: v4Mask)
            var v4Routes: [NEIPv4Route] = []
            var v4Exclude: [NEIPv4Route] = []

            let v4RouteIt = options.getInet4RouteAddress()!
            if v4RouteIt.hasNext() {
                while v4RouteIt.hasNext() {
                    let p = v4RouteIt.next()!
                    v4Routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
                }
            } else {
                v4Routes.append(NEIPv4Route.default())
            }
            let v4ExcludeIt = options.getInet4RouteExcludeAddress()!
            while v4ExcludeIt.hasNext() {
                let p = v4ExcludeIt.next()!
                v4Exclude.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
            }
            v4.includedRoutes = v4Routes
            v4.excludedRoutes = v4Exclude
            settings.ipv4Settings = v4

            // IPv6
            var v6Address: [String] = []
            var v6Prefixes: [NSNumber] = []
            let v6It = options.getInet6Address()!
            while v6It.hasNext() {
                let p = v6It.next()!
                v6Address.append(p.address())
                v6Prefixes.append(NSNumber(value: p.prefix()))
            }
            let v6 = NEIPv6Settings(addresses: v6Address, networkPrefixLengths: v6Prefixes)
            var v6Routes: [NEIPv6Route] = []
            var v6Exclude: [NEIPv6Route] = []

            let v6RouteIt = options.getInet6RouteAddress()!
            if v6RouteIt.hasNext() {
                while v6RouteIt.hasNext() {
                    let p = v6RouteIt.next()!
                    v6Routes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
                }
            } else {
                v6Routes.append(NEIPv6Route.default())
            }
            let v6ExcludeIt = options.getInet6RouteExcludeAddress()!
            while v6ExcludeIt.hasNext() {
                let p = v6ExcludeIt.next()!
                v6Exclude.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
            }
            v6.includedRoutes = v6Routes
            v6.excludedRoutes = v6Exclude
            settings.ipv6Settings = v6
        }

        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let server = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxySettings.httpServer = server
            proxySettings.httpsServer = server
            proxySettings.httpEnabled = true
            proxySettings.httpsEnabled = true
            settings.proxySettings = proxySettings
        }

        networkSettings = settings

        // setTunnelNetworkSettings отвечает в другой очереди, поэтому ждём семафором.
        let semaphore = DispatchSemaphore(value: 0)
        var applyError: Error?
        tunnel.setTunnelNetworkSettings(settings) { error in
            applyError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let applyError { throw applyError }

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd != -1 {
            ret0_.pointee = fd
        } else {
            throw NSError(domain: "missing file descriptor", code: 0)
        }
    }

    // MARK: - Простые заглушки

    func usePlatformAutoDetectControl() -> Bool { false }
    func autoDetectControl(_: Int32) throws {}

    func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?, destinationPort _: Int32, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "not implemented", code: 0)
    }

    func packageName(byUid _: Int32, error _: NSErrorPointer) -> String { "" }

    func uid(byPackageName _: String?, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "not implemented", code: 0)
    }

    func useProcFS() -> Bool { false }

    func writeLog(_ message: String?) {
        guard let message else { return }
        NSLog("[sing-box] %@", message)
    }

    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    func readWIFIState() -> LibboxWIFIState? { nil }
    func send(_: LibboxNotification?) throws {}
    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func clearDNSCache() {
        guard let networkSettings else { return }
        tunnel.reasserting = true
        tunnel.setTunnelNetworkSettings(nil) { _ in }
        tunnel.setTunnelNetworkSettings(networkSettings) { _ in }
        tunnel.reasserting = false
    }

    // MARK: - Мониторинг сети

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        let semaphore = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onUpdateDefaultInterface(listener, path)
            semaphore.signal()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.onUpdateDefaultInterface(listener, path)
            }
        }
        monitor.start(queue: DispatchQueue.global())
        semaphore.wait()
    }

    private func onUpdateDefaultInterface(_ listener: LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath) {
        if path.status == .unsatisfied || path.availableInterfaces.isEmpty {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
        } else {
            let defaultInterface = path.availableInterfaces[0]
            listener.updateDefaultInterface(defaultInterface.name, interfaceIndex: Int32(defaultInterface.index), isExpensive: path.isExpensive, isConstrained: path.isConstrained)
        }
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let nwMonitor else {
            throw NSError(domain: "NWMonitor not started", code: 0)
        }
        let path = nwMonitor.currentPath
        if path.status == .unsatisfied {
            return NetworkInterfaceArray([])
        }
        var interfaces: [LibboxNetworkInterface] = []
        for it in path.availableInterfaces {
            let interface = LibboxNetworkInterface()
            interface.name = it.name
            interface.index = Int32(it.index)
            switch it.type {
            case .wifi: interface.type = LibboxInterfaceTypeWIFI
            case .cellular: interface.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: interface.type = LibboxInterfaceTypeEthernet
            default: interface.type = LibboxInterfaceTypeOther
            }
            interfaces.append(interface)
        }
        return NetworkInterfaceArray(interfaces)
    }

    final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
        private var iterator: IndexingIterator<[LibboxNetworkInterface]>
        private var nextValue: LibboxNetworkInterface?

        init(_ array: [LibboxNetworkInterface]) {
            iterator = array.makeIterator()
        }

        func hasNext() -> Bool {
            nextValue = iterator.next()
            return nextValue != nil
        }

        func next() -> LibboxNetworkInterface? { nextValue }
    }
}
