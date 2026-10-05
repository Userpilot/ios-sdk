//
//  NetworkMonitor.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Updated for real internet connectivity detection on 19/01/2026.
//  © 2025 Userpilot. All rights reserved.
//
//  `NetworkMonitor` monitors network connectivity changes and validates real internet access.
//  It uses NWPathMonitor for interface detection and periodic reachability checks to verify actual
//  internet connectivity.
//

import Foundation
import Network

/// Receives readiness and availability changes on the monitor's current queue.
internal protocol NetworkMonitoringDelegate: AnyObject {
    func networkMonitorDidUpdate(isReady: Bool, isNetworkAvailable: Bool)
}

/// Connectivity snapshots and lifecycle control. Readiness re-arms after backgrounding;
/// availability retains its last verified value until the next check finishes.
internal protocol NetworkMonitoring: AnyObject {
    var isNetworkAvailable: Bool { get }
    var connectionType: ConnectionType { get }
    var isConnectedViaWiFi: Bool { get }
    var isConnectedViaCellular: Bool { get }
    var isReady: Bool { get }
    var delegate: NetworkMonitoringDelegate? { get set }

    func startMonitoring()
    func stopMonitoring()

    /// Event-driven recovery on a live interface; internally throttled.
    func recheckIfOffline()
}

// swiftlint:disable file_length

// MARK: - NetworkMonitor

// swiftlint:disable type_body_length
/// `NetworkMonitor` is responsible for monitoring network connectivity changes and validating
/// real internet access through reachability checks. Probe work stays on `networkQueue`;
/// cross-thread snapshots retain their existing `stateQueue` synchronization.
internal class NetworkMonitor: NetworkMonitoring {

    // MARK: - Properties

    private let storage: DataStoring
    private let logger: Logging
    weak var delegate: NetworkMonitoringDelegate?

    private let networkQueue = DispatchQueue(
        label: Constants.DispatchQueues.networkMonitor,
        qos: .utility
    )
    private let networkQueueKey = DispatchSpecificKey<Bool>()

    private let stateQueue = DispatchQueue(
        label: Constants.DispatchQueues.networkMonitorState, attributes: .concurrent)

    private var pathMonitor: NWPathMonitor?
    private var debounceWorkItem: DispatchWorkItem?
    /// Interface-change debounce. `var` so tests can collapse it.
    internal var debounceDelay: TimeInterval = 0.3

    // Reachability check properties
    // Active validation targets first-party Userpilot hosts only — probing public
    // hosts (Google/Apple/Cloudflare) from customer apps is a privacy/firewall problem.
    // Multiple first-party hosts are rotated so one unreachable endpoint can't
    // falsely report "no internet". Side benefit: "Userpilot backend unreachable"
    // also routes events to offline storage.
    private let reachabilityTimeout: TimeInterval = 5.0
    private var currentReachabilityIndex = 0
    // Created, completed, and cancelled on networkQueue.
    private var cancelReachabilityProbe: (() -> Void)?

    /// Stands in for ``checkInternetReachability(host:completion:)`` so tests can drive a
    /// failing probe to recovery without opening real sockets. `nil` in production.
    internal var reachabilityProbe: ((String, @escaping (Bool) -> Void) -> Void)?

    /// Shortest gap between two recovery probes driven by ``recheckIfOffline()``.
    /// `var` so tests can collapse it.
    internal var reachabilityRecheckInterval: TimeInterval = 10.0

    // Backing state (accessed via concurrent queue)
    private var _isNetworkAvailable: Bool = false  // Start pessimistic until verified
    private var _hasInterfaceConnection: Bool = false  // Interface level connectivity
    private var _hasInternetAccess: Bool = false  // Real internet connectivity
    private var _connectionType: ConnectionType = .unknown
    private var _isReady: Bool = false
    private var _isCheckingReachability: Bool = false
    /// When the last probe started, so `recheckIfOffline()` can throttle.
    private var _lastReachabilityCheckAt: TimeInterval = 0

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
        let config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = config.logger
        networkQueue.setSpecific(key: networkQueueKey, value: true)
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - NetworkMonitoring

    func startMonitoring() {
        tryCatch {
            guard pathMonitor == nil else { return }

            // Start path monitoring
            pathMonitor = NWPathMonitor()

            pathMonitor?.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }

                let hasInterface = path.hasInterfaceConnection
                let connType = path.connectionType

                self.logger.debug(
                    "🌐 Interface status: %{public}@, Type: %{public}@",
                    hasInterface ? "Connected" : "Disconnected",
                    connType.logDescription)

                // Update interface state
                self.updateInterfaceState(hasInterface: hasInterface, connectionType: connType)
            }

            pathMonitor?.start(queue: networkQueue)

            // Trigger initial reachability check
            networkQueue.async { [weak self] in
                self?.performReachabilityCheck()
            }

            logger.debug("🌐 NetworkMonitor started with internet validation")
        }
    }

    func stopMonitoring() {
        tryCatch {
            let stop = {
                self.debounceWorkItem?.cancel()
                self.debounceWorkItem = nil

                self.pathMonitor?.pathUpdateHandler = nil
                self.pathMonitor?.cancel()
                self.pathMonitor = nil

                // Discard the probe before resetting readiness; cancellation is not a result.
                self.cancelReachabilityProbe?()
                self.cancelReachabilityProbe = nil
                self.markNotReadyForBackground()

                self.logger.debug("🌐 NetworkMonitor stopped")
            }

            // A callback or deinit can stop us from networkQueue itself.
            if DispatchQueue.getSpecific(key: networkQueueKey) == true {
                stop()
            } else {
                networkQueue.sync(execute: stop)
            }
        }
    }

    /**
     * Background middle-ground: readiness re-arms (foreground events buffer in the
     * initial queue until connectivity is re-verified — the network can change while
     * suspended), but the last-known AVAILABILITY is preserved so backgrounding never
     * falsely reports "offline" and routes events to local storage. Also releases a
     * possibly in-flight reachability check so the next one isn't skipped.
     */
    private func markNotReadyForBackground() {
        var lastKnownAvailability = false
        stateQueue.sync(flags: .barrier) {
            lastKnownAvailability = _isNetworkAvailable
            _isReady = false
            _isCheckingReachability = false
            _hasInterfaceConnection = false
        }
        delegate?.networkMonitorDidUpdate(isReady: false, isNetworkAvailable: lastKnownAvailability)
    }

    // MARK: - Reachability Checks
    // Removed periodic polling to save battery and resources.
    // We now rely on NWPathMonitor updates to trigger checks.

    private func performReachabilityCheck() {
        // Read current interface state
        let hasInterface = stateQueue.sync { _hasInterfaceConnection }

        // Skip check if no interface connection
        guard hasInterface else {
            return
        }

        // Skip if already checking
        let isChecking = stateQueue.sync { _isCheckingReachability }
        guard !isChecking else { return }

        stateQueue.async(flags: .barrier) { [weak self] in
            self?._isCheckingReachability = true
            self?._lastReachabilityCheckAt = Date().timeIntervalSince1970
        }

        // Rotate through first-party hosts for redundancy
        let reachabilityHosts = NetworkMonitor.makeReachabilityHosts(socketURL: storage.socketURL)
        guard !reachabilityHosts.isEmpty else {
            // Always release the checking flag on early exit, or every future
            // reachability check would be skipped forever.
            stateQueue.async(flags: .barrier) { [weak self] in
                self?._isCheckingReachability = false
            }
            updateInternetAccessState(hasAccess: false)
            return
        }
        if currentReachabilityIndex >= reachabilityHosts.count {
            currentReachabilityIndex = 0
        }
        let host = reachabilityHosts[currentReachabilityIndex]
        currentReachabilityIndex = (currentReachabilityIndex + 1) % reachabilityHosts.count

        let probe = reachabilityProbe ?? { [weak self] probeHost, completion in
            self?.checkInternetReachability(host: probeHost, completion: completion)
        }

        probe(host) { [weak self] hasAccess in
            guard let self = self else { return }

            self.stateQueue.async(flags: .barrier) {
                self._isCheckingReachability = false
            }

            self.updateInternetAccessState(hasAccess: hasAccess)
        }
    }

    // MARK: - Recovery

    /// Re-probes reachability when the SDK believes it is offline.
    ///
    /// `NWPathMonitor` reports INTERFACE transitions only, so a probe that failed while the
    /// interface stayed `.satisfied` — captive portal, backend outage, transient DNS — would
    /// otherwise pin the SDK offline until the interface flapped or the app was backgrounded,
    /// with every event routed to local storage in the meantime.
    ///
    /// Driven by event publishing rather than by a timer: while the app is idle there is nothing
    /// to send, so being marked offline costs nothing and a wake-up would buy nothing. The moment
    /// something does need sending, this re-checks. Throttled to one probe per
    /// ``reachabilityRecheckInterval`` so a burst of events cannot turn into a burst of probes.
    func recheckIfOffline() {
        var shouldProbe = false
        stateQueue.sync(flags: .barrier) {
            let now = Date().timeIntervalSince1970
            guard !_isNetworkAvailable,
                  _hasInterfaceConnection,
                  !_isCheckingReachability,
                  now - _lastReachabilityCheckAt >= reachabilityRecheckInterval
            else { return }
            shouldProbe = true
        }
        guard shouldProbe else { return }

        logger.debug("🌐 Offline with a live interface - re-checking reachability")
        networkQueue.async { [weak self] in
            self?.performReachabilityCheck()
        }
    }

    /// Builds the first-party probe host list: the configured socket endpoint plus
    /// the settings and experience API hosts. Never public hosts.
    static func makeReachabilityHosts(socketURL: String) -> [String] {
        var hosts: [String] = []
        appendHost(from: socketURL, to: &hosts)
        appendHost(from: Constants.RemoteSource.settingsBaseURL, to: &hosts)
        appendHost(from: Environment.getExperienceContentUrl(), to: &hosts)
        return hosts
    }

    private static func appendHost(from urlString: String, to hosts: inout [String]) {
        guard !urlString.isEmpty else { return }
        let normalizedURLString = urlString.contains("://") ? urlString : "https://\(urlString)"
        guard let host = URL(string: normalizedURLString)?.host, !host.isEmpty else { return }
        if !hosts.contains(host) {
            hosts.append(host)
        }
    }

    private func checkInternetReachability(host: String, completion: @escaping (Bool) -> Void) {
        // Use NWConnection for a lightweight reachability check
        guard let port = NWEndpoint.Port(rawValue: 443) else {
            completion(false)
            return
        }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)

        var didComplete = false
        let timeoutWorkItem = DispatchWorkItem { [weak self, weak connection] in
            guard !didComplete else { return }
            didComplete = true
            connection?.stateUpdateHandler = nil
            connection?.cancel()
            self?.cancelReachabilityProbe = nil
            completion(false)
        }

        cancelReachabilityProbe = {
            didComplete = true
            timeoutWorkItem.cancel()
            connection.stateUpdateHandler = nil
            connection.cancel()
        }

        // Settles the probe from a terminal connection state. A `.cancelled` connection is
        // already cancelled, so it skips `cancel()`.
        let settle: (_ reachable: Bool, _ cancelConnection: Bool) -> Void = { [weak self] reachable, cancel in
            didComplete = true
            timeoutWorkItem.cancel()
            connection.stateUpdateHandler = nil
            if cancel { connection.cancel() }
            self?.cancelReachabilityProbe = nil
            completion(reachable)
        }

        connection.stateUpdateHandler = { [weak self] state in
            guard !didComplete else { return }

            switch state {
            case .ready:
                self?.logger.debug("🌐 Reachability check succeeded: %{public}@", host)
                settle(true, true)

            case .failed(let error):
                self?.logger.debug(
                    "🌐 Reachability check failed: %{public}@ - %{public}@",
                    host, error.localizedDescription)
                settle(false, true)

            case .cancelled:
                settle(false, false)

            default:
                break
            }
        }

        connection.start(queue: networkQueue)
        networkQueue.asyncAfter(deadline: .now() + reachabilityTimeout, execute: timeoutWorkItem)
    }

    // MARK: - State Management

    /// Entry point for an interface transition. Internal rather than private so tests can stand
    /// in for `NWPathMonitor` without opening a real path monitor.
    internal func updateInterfaceState(hasInterface: Bool, connectionType: ConnectionType) {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.applyInterfaceState(hasInterface: hasInterface, connectionType: connectionType)
        }

        debounceWorkItem = workItem
        networkQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    /// Applies the settled interface update on `networkQueue`; an unchanged first update must
    /// still resolve readiness so startup events can leave the initial analytics queue.
    private func applyInterfaceState(hasInterface: Bool, connectionType: ConnectionType) {
        let previous = stateQueue.sync {
            (hasInterface: _hasInterfaceConnection, connectionType: _connectionType)
        }
        let interfaceChanged = previous.hasInterface != hasInterface
        let typeChanged = previous.connectionType != connectionType

        guard interfaceChanged || typeChanged else {
            let wasReady = stateQueue.sync { _isReady }
            if !wasReady {
                if hasInterface {
                    performReachabilityCheck()
                } else {
                    updateInternetAccessState(hasAccess: false)
                }
            }
            return
        }

        stateQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self._hasInterfaceConnection = hasInterface
            self._connectionType = connectionType
        }

        if interfaceChanged {
            if hasInterface {
                logger.debug("🌐 Network interface connected, checking internet access...")
                performReachabilityCheck()
            } else {
                logger.debug("🌐 Network interface disconnected")
                updateInternetAccessState(hasAccess: false)
            }
        }
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
            let typeString = connType.logDescription
            if hasAccess {
                logger.debug("🌐 ✅ Internet access verified - Connection: %{public}@", typeString)
            } else {
                logger.debug("🌐 ❌ No internet access - Connection: %{public}@", typeString)
            }
        }

        let shouldNotify = accessChanged || !wasReady
        if shouldNotify {
            delegate?.networkMonitorDidUpdate(isReady: true, isNetworkAvailable: hasAccess)
        }
    }

}
// swiftlint:enable type_body_length
