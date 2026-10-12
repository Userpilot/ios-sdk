//
//  InstanceRegistry.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/06/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Records live SDK instances, their explicit default claim and presentation order.
//  The runtime owns registration; consumers read this registry without starting services.
//

import Foundation

/// Read-only instance membership and fallback routing. Lifecycle writes belong to UserpilotRuntime.
internal protocol InstanceRegistering: AnyObject {
    var `default`: Userpilot? { get }
    var allInstances: [Userpilot] { get }
    func instance(forToken token: String) -> Userpilot?
    func registrationIndex(forToken token: String) -> Int?
    func isRegistered(_ instance: Userpilot) -> Bool
}

internal extension InstanceRegistering {
    /// Same-token facades share a canonical owner. A replacement registration is a different lifetime.
    func isRegistered(_ instance: Userpilot) -> Bool {
        self.instance(forToken: instance.config.token) === instance.canonicalInstance
    }
}

/// ARC owns instance lifetime on iOS; the registry must never keep a host's SDK instance alive.
private final class InstanceRegistration {
    weak var instance: Userpilot?
    let identity: ObjectIdentifier

    init(_ instance: Userpilot) {
        self.instance = instance
        identity = ObjectIdentifier(instance)
    }
}

/// Thread-safe membership only: no logging, native callbacks or dependency construction under the lock.
internal final class InstanceRegistry: InstanceRegistering {
    // A weak read can release the last temporary strong reference on return. ARC may then
    // unregister that instance on this thread, so lifecycle reentry must remain safe.
    private let lock = NSRecursiveLock()
    private var instances: [String: InstanceRegistration] = [:]
    private var registrationOrder: [String] = []
    private weak var defaultInstance: Userpilot?

    var `default`: Userpilot? {
        lock.withLock { defaultInstance }
    }

    /// Registration order is stable for scope tie-breaking and overlay levels, never default selection.
    var allInstances: [Userpilot] {
        lock.withLock { registrationOrder.compactMap { instances[$0]?.instance } }
    }

    func instance(forToken token: String) -> Userpilot? {
        lock.withLock { instances[token]?.instance }
    }

    func registrationIndex(forToken token: String) -> Int? {
        lock.withLock { registrationOrder.firstIndex(of: token) }
    }

    /// Returns the existing default token if this instance's default claim was rejected.
    @discardableResult
    func register(_ instance: Userpilot) -> String? {
        lock.withLock {
            let token = instance.config.token
            instances[token] = InstanceRegistration(instance)
            if !registrationOrder.contains(token) { registrationOrder.append(token) }
            guard instance.config.isDefault else { return nil }
            if let current = defaultInstance, current !== instance { return current.config.token }
            defaultInstance = instance
            return nil
        }
    }

    /// Compare identity, not just token: releasing a duplicate facade cannot unregister its owner.
    /// The stored identity also works during deinit, when Swift has already cleared weak references.
    func unregister(_ instance: Userpilot) {
        lock.withLock {
            let token = instance.config.token
            guard instances[token]?.identity == ObjectIdentifier(instance) else { return }
            instances.removeValue(forKey: token)
            registrationOrder.removeAll { instances[$0]?.instance == nil }
            if defaultInstance === instance { defaultInstance = nil }
        }
    }
}
