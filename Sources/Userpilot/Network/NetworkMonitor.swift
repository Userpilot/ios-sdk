//
//  NetworkMonitor.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2025.
//  Updated for real internet connectivity detection on 19/01/2026.
//  © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `NetworkMonitor` monitors network connectivity changes and validates real internet access.
//  It uses NWPathMonitor for interface detection and periodic reachability checks to verify actual
//  internet connectivity.
//

import Foundation
import Network

// MARK: - Connection Type

/// Enum representing connection types
internal enum ConnectionType {
    case wifi
    case cellular
    case wiredEthernet
    case unknown
}

// MARK: - Protocols

/// `NetworkMonitoring` defines methods and properties for monitoring network connectivity.
internal protocol NetworkMonitoring: AnyObject {
    /// Indicates whether the device has an active network connection with real internet access.
    var isNetworkAvailable: Bool { get }

    /// Current connection type
    var connectionType: ConnectionType { get }

    /// Check if connected via WiFi
    var isConnectedViaWiFi: Bool { get }

    /// Check if connected via Cellular
    var isConnectedViaCellular: Bool { get }

    /// Indicates whether the monitor has received its first network state update
    var isReady: Bool { get }

    /// Starts monitoring network connectivity changes.
    func startMonitoring()

    /// Stops monitoring network connectivity changes.
    func stopMonitoring()
}

// MARK: - NetworkMonitor

/// `NetworkMonitor` is responsible for monitoring network connectivity changes and validating
/// real internet access through reachability checks.
internal class NetworkMonitor: NetworkMonitoring {

    // MARK: - Properties

    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let logger: Logging

    private let networkQueue = DispatchQueue(
        label: Constants.DispatchQueues.networkMonitor,
        qos: .utility
    )

    private let stateQueue = DispatchQueue(
        label: "com.userpilot.network.state", attributes: .concurrent)

    private var pathMonitor: NWPathMonitor?
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3

    // Reachability check properties
    // private var reachabilityTimer: DispatchSourceTimer? - Removed
    // private let reachabilityCheckInterval: TimeInterval = 10.0 - Removed
    private let reachabilityTimeout: TimeInterval = 5.0
    private var reachabilityHosts = ["www.google.com", "www.apple.com", "1.1.1.1"]
    private var currentReachabilityIndex = 0

    // Backing state (accessed via concurrent queue)
    private var _isNetworkAvailable: Bool = false  // Start pessimistic until verified
    private var _hasInterfaceConnection: Bool = false  // Interface level connectivity
    private var _hasInternetAccess: Bool = false  // Real internet connectivity
    private var _connectionType: ConnectionType = .unknown
    private var _isReady: Bool = false
    private var _isCheckingReachability: Bool = false

    /// Indicates whether the device has real internet connectivity
    var isNetworkAvailable: Bool {
        stateQueue.sync { _isNetworkAvailable }
    }

    /// Current connection type
    var connectionType: ConnectionType {
        stateQueue.sync { _connectionType }
    }

    /// Check if connected via WiFi with internet access
    var isConnectedViaWiFi: Bool {
        isNetworkAvailable && connectionType == .wifi
    }

    /// Check if connected via Cellular with internet access
    var isConnectedViaCellular: Bool {
        isNetworkAvailable && connectionType == .cellular
    }

    /// Indicates whether the monitor has received its first network state update.
    var isReady: Bool {
        stateQueue.sync { _isReady }
    }

    // MARK: - Initialization

    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.logger = config.logger

        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - NetworkMonitoring

    func startMonitoring() {
        tryCatch {
            // Start path monitoring
            pathMonitor = NWPathMonitor()

            pathMonitor?.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }

                let hasInterface = path.status == .satisfied && path.availableInterfaces.count > 0
                let connType = self.determineConnectionType(path)

                self.logger.debug(
                    "🌐 Interface status: %{public}@, Type: %{public}@",
                    hasInterface ? "Connected" : "Disconnected",
                    self.connectionTypeString(connType))

                // Update interface state
                self.updateInterfaceState(hasInterface: hasInterface, connectionType: connType)
            }

            pathMonitor?.start(queue: networkQueue)

            // Trigger initial reachability check
            self.performReachabilityCheck()

            logger.debug("🌐 NetworkMonitor started with internet validation")
        }
    }

    func stopMonitoring() {
        tryCatch {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil

            pathMonitor?.cancel()
            pathMonitor = nil

            logger.debug("🌐 NetworkMonitor stopped")
        }
    }

    // MARK: - Reachability Checks
    // Removed periodic polling to save battery and resources.
    // We now rely on NWPathMonitor updates to trigger checks.

    private func performReachabilityCheck() {
        // Read current interface state
        let hasInterface = stateQueue.sync { _hasInterfaceConnection }

        // Skip check if no interface connection
        guard hasInterface else {
            updateInternetAccessState(hasAccess: false)
            return
        }

        // Skip if already checking
        let isChecking = stateQueue.sync { _isCheckingReachability }
        guard !isChecking else { return }

        stateQueue.async(flags: .barrier) { [weak self] in
            self?._isCheckingReachability = true
        }

        // Rotate through reachability hosts for redundancy
        let host = reachabilityHosts[currentReachabilityIndex]
        currentReachabilityIndex = (currentReachabilityIndex + 1) % reachabilityHosts.count

        checkInternetReachability(host: host) { [weak self] hasAccess in
            guard let self = self else { return }

            self.stateQueue.async(flags: .barrier) {
                self._isCheckingReachability = false
            }

            self.updateInternetAccessState(hasAccess: hasAccess)
        }
    }

    private func checkInternetReachability(host: String, completion: @escaping (Bool) -> Void) {
        // Use NWConnection for a lightweight reachability check
        guard let port = NWEndpoint.Port(rawValue: 443) else {
            completion(false)
            return
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: .tcp
        )

        var didComplete = false
        let timeoutWorkItem = DispatchWorkItem { [weak connection] in
            guard !didComplete else { return }
            didComplete = true
            connection?.cancel()
            completion(false)
        }

        connection.stateUpdateHandler = { [weak self] state in
            guard !didComplete else { return }

            switch state {
            case .ready:
                didComplete = true
                timeoutWorkItem.cancel()
                connection.cancel()
                self?.logger.debug("🌐 Reachability check succeeded: %{public}@", host)
                completion(true)

            case .failed(let error):
                didComplete = true
                timeoutWorkItem.cancel()
                connection.cancel()
                self?.logger.debug(
                    "🌐 Reachability check failed: %{public}@ - %{public}@",
                    host, error.localizedDescription)
                completion(false)

            case .cancelled:
                if !didComplete {
                    didComplete = true
                    timeoutWorkItem.cancel()
                    completion(false)
                }

            default:
                break
            }
        }

        connection.start(queue: networkQueue)
        networkQueue.asyncAfter(deadline: .now() + reachabilityTimeout, execute: timeoutWorkItem)
    }

    // MARK: - State Management

    private func updateInterfaceState(hasInterface: Bool, connectionType: ConnectionType) {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            var oldInterfaceState = false
            var oldType: ConnectionType = .unknown

            self.stateQueue.sync {
                oldInterfaceState = self._hasInterfaceConnection
                oldType = self._connectionType
            }

            let interfaceChanged = oldInterfaceState != hasInterface
            let typeChanged = oldType != connectionType

            guard interfaceChanged || typeChanged else { return }

            self.stateQueue.async(flags: .barrier) {
                self._hasInterfaceConnection = hasInterface
                self._connectionType = connectionType
            }

            if interfaceChanged {
                if hasInterface {
                    self.logger.debug("🌐 Network interface connected, checking internet access...")
                    // Trigger immediate reachability check
                    self.performReachabilityCheck()
                } else {
                    self.logger.debug("🌐 Network interface disconnected")
                    self.updateInternetAccessState(hasAccess: false)
                }
            }
        }

        debounceWorkItem = workItem
        networkQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    private func updateInternetAccessState(hasAccess: Bool) {
        var oldAccessState = false
        var oldNetworkState = false
        var wasReady = false
        var connType: ConnectionType = .unknown

        stateQueue.sync {
            oldAccessState = _hasInternetAccess
            oldNetworkState = _isNetworkAvailable
            wasReady = _isReady
            connType = _connectionType
        }

        let accessChanged = oldAccessState != hasAccess
        let networkChanged = oldNetworkState != hasAccess

        guard accessChanged || networkChanged || !wasReady else { return }

        stateQueue.async(flags: .barrier) { [weak self] in
            self?._hasInternetAccess = hasAccess
            self?._isNetworkAvailable = hasAccess
            self?._isReady = true
        }

        if accessChanged || !wasReady {
            let typeString = connectionTypeString(connType)
            if hasAccess {
                logger.debug("🌐 ✅ Internet access verified - Connection: %{public}@", typeString)
            } else {
                logger.debug("🌐 ❌ No internet access - Connection: %{public}@", typeString)
            }
        }
    }

    // MARK: - Helper Methods

    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }

    private func connectionTypeString(_ type: ConnectionType) -> String {
        switch type {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}
