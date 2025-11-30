//
//  NetworkMonitor.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2025.
//  Updated for performance optimizations on 13/10/2025.
//  © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `NetworkMonitor` monitors network connectivity changes and provides real-time network availability status.
//  It uses NWPathMonitor to detect network state changes with debouncing to prevent rapid successive updates.
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
    /// Indicates whether the device has an active network connection.
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

/// `NetworkMonitor` is responsible for monitoring network connectivity changes and providing
/// real-time network availability status.
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
    private let debounceDelay: TimeInterval = 1.0

    // Backing state (accessed via concurrent queue)
    // Start with optimistic assumption of network availability
    private var _isNetworkAvailable: Bool = true
    private var _connectionType: ConnectionType = .unknown
    private var _isReady: Bool = false

    /// Indicates whether the device has an active network connection. This property is updated
    /// automatically as network state changes.
    /// Initially assumes network is available until first path update is received.
    var isNetworkAvailable: Bool {
        stateQueue.sync { _isNetworkAvailable }
    }

    /// Current connection type
    var connectionType: ConnectionType {
        stateQueue.sync { _connectionType }
    }

    /// Check if connected via WiFi
    var isConnectedViaWiFi: Bool {
        isNetworkAvailable && connectionType == .wifi
    }

    /// Check if connected via Cellular
    var isConnectedViaCellular: Bool {
        isNetworkAvailable && connectionType == .cellular
    }

    /// Indicates whether the monitor has received its first network state update.
    /// Returns false during initial setup phase (typically 1-3 seconds).
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
            pathMonitor = NWPathMonitor()

            pathMonitor?.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }

                // Compute new state
                let isConnected = path.status == .satisfied
                let connType: ConnectionType

                if path.usesInterfaceType(.wifi) {
                    connType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    connType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    connType = .wiredEthernet
                } else {
                    connType = .unknown
                }

                // Debounced state update
                self.updateNetworkState(isConnected: isConnected, connectionType: connType)
            }

            pathMonitor?.start(queue: networkQueue)
            logger.debug("🌐 NetworkMonitor started")
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

    // MARK: - Private Methods

    /// Updates network state with debouncing to prevent rapid successive updates.
    private func updateNetworkState(isConnected: Bool, connectionType: ConnectionType) {
        // Cancel any pending update
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Capture old state atomically
            var oldState: Bool = false
            var oldType: ConnectionType = .unknown
            var wasReady: Bool = false

            stateQueue.sync {
                oldState = self._isNetworkAvailable
                oldType = self._connectionType
                wasReady = self._isReady
            }

            let stateChanged = oldState != isConnected || oldType != connectionType
            let readyStateChanged = !wasReady

            // Update only if needed
            guard stateChanged || readyStateChanged else { return }

            // Write new values with barrier to avoid race
            stateQueue.async(flags: .barrier) {
                self._isNetworkAvailable = isConnected
                self._connectionType = connectionType
                self._isReady = true
            }

            // Create log only after verifying state change
            if stateChanged || readyStateChanged {
                let message = self.createLogMessage(
                    isConnected: isConnected, connectionType: connectionType)
                self.logger.debug("%{public}@", message)
            }
        }

        debounceWorkItem = workItem
        networkQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    /// Creates a descriptive log message based on network status and connection type.
    private func createLogMessage(isConnected: Bool, connectionType: ConnectionType) -> String {
        let status = isConnected ? "Connected" : "Disconnected"
        let typeString = connectionTypeString(connectionType)
        return "🌐 Network status: \(status) - Connection type: \(typeString)"
    }

    /// Converts connection type to a readable string.
    private func connectionTypeString(_ type: ConnectionType) -> String {
        switch type {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}
