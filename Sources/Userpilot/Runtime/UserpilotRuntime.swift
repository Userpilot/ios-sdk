//
//  UserpilotRuntime.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns process-wide SDK infrastructure and serializes instance registration.
//  Account-specific services remain in each Userpilot instance's dependency container.
//

import Foundation

/// The single native-hook entry point. Constructing the runtime installs no hooks and starts no scans.
internal final class UserpilotRuntime {
    static let shared = UserpilotRuntime()

    let instanceRegistry: InstanceRegistry
    let instanceResolver: InstanceResolving
    let captureIntegration: AutoCaptureIntegrating
    let scanCache: SwiftUIScanCache

    /// Serializes get-or-create, registration and startup. Startup may enqueue UI work, never wait for main.
    private let lifecycleLock = NSRecursiveLock()

    init() {
        let registry = InstanceRegistry()
        instanceRegistry = registry
        instanceResolver = InstanceResolver(registry: registry)
        captureIntegration = AutoCaptureIntegration(registry: registry)
        scanCache = SwiftUIScanCache(registry: registry, instanceResolver: instanceResolver)
    }

    /// Lookup, construction and startup share one lock: a repeated token returns the original object.
    /// Register before eager services are built so native callbacks can resolve their owner during startup.
    func initializeInstance(config: Userpilot.Config, make: () -> Userpilot) -> Userpilot {
        lifecycleLock.withLock {
            if let existing = instanceRegistry.instance(forToken: config.token) {
                existing.config.logger.error(
                    // swiftlint:disable:next line_length
                    "⚠️ Userpilot already initialized for token %{public}@; returning the existing instance. The supplied config was discarded.",
                    existing.config.token
                )
                return existing
            }
            StorageMigrator.runIfNeeded(forToken: config.token)
            let instance = make()
            if let existingDefaultToken = instanceRegistry.register(instance) {
                instance.config.logger.error(
                    // swiftlint:disable:next line_length
                    "⚠️ isDefault is already claimed by token %{public}@; ignoring isDefault=true on token %{public}@. Only one Userpilot instance per process can be the default; unattributed events will continue to route to %{public}@.",
                    existingDefaultToken,
                    instance.config.token,
                    existingDefaultToken
                )
            }
            instance.initializeInstance()
            return instance
        }
    }

    /// ARC releases instance services. Removing one registration never stops another instance's capture.
    func removeInstance(_ instance: Userpilot) {
        instanceRegistry.unregister(instance)
    }
}
