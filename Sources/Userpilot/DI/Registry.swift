//
//  Registry.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `Userpilot.Registry` holds weak references to every live `Userpilot` instance
//  in the process, plus a single `default` slot used by SDK fallback routing.
//  It is the source of truth for multi-instance routing (autocapture scoping,
//  experience overlay window levels, and same-token double-init detection).
//

import Foundation

/// The read-only contract every registry consumer needs.
///
/// Lifecycle mutation (`register` / `unregister`) deliberately stays off this
/// protocol and on the concrete `Userpilot.Registry`, because only `Userpilot`
/// itself drives registration (from `init` / `deinit`). Consumers only ever
/// *read* the registry, so exposing reads alone keeps the seam honest.
internal protocol InstanceRegistering: AnyObject {

    /// The SDK fallback instance: the instance that opted in via
    /// `Config.defaultInstance(true)` (first claimant wins), or `nil` when no
    /// instance currently holds the default role.
    var `default`: Userpilot? { get }

    /// All currently live instances, ignoring deallocated entries.
    var allInstances: [Userpilot] { get }

    /// Look up a live instance by its configured token.
    func instance(forToken token: String) -> Userpilot?

    /// Deterministic registration index for a token, used by `ExperienceOverlayWindow`
    /// to allocate `windowLevel`. `nil` when the token is unknown.
    func registrationIndex(forToken token: String) -> Int?
}

/// Internal wrapper so a Swift `Dictionary` can hold weak references to `Userpilot`.
/// Kept file-scoped (not nested) to avoid a 3-level type nesting depth in `Registry`.
private final class WeakUserpilotContainer {
    weak var instance: Userpilot?

    init(_ instance: Userpilot) {
        self.instance = instance
    }
}

extension Userpilot {

    /// Process-wide registry of live `Userpilot` instances.
    ///
    /// - Holds weak references so SDK instances are not retained beyond their natural owner
    ///   (the host app or the embedding SDK).
    /// - Resolves the SDK fallback instance on read:
    ///   the `defaultInstance(true)` claimant (first claimant wins), else `nil`.
    ///   Resolution is claim-based, so it is independent of registration order.
    /// - Preserves the order in which instances were registered so consumers (e.g. the
    ///   experience overlay window) can derive a deterministic z-ordering. This
    ///   ordering is used *only* for `registrationIndex` / window levels, never for
    ///   default resolution.
    ///
    /// A pure data structure: it does no logging and triggers no autocapture side
    /// effects. The owning `Userpilot` drives `register` / `unregister` (from
    /// `init` / `deinit`) and owns the warnings + swizzler refresh, keeping this
    /// type free of those dependencies and mirroring the Android registry.
    ///
    /// Conforms to `InstanceRegistering` so consumers can depend on the read
    /// surface and be injected with a substitute in tests. `register` /
    /// `unregister` stay off that protocol because only `Userpilot` drives them.
    internal final class Registry: InstanceRegistering {

        // MARK: - Shared

        /// The single process-wide registry. There is no reason to construct another.
        static let shared = Registry()

        // MARK: - State

        /// Concurrent queue used for synchronized reads / barriered writes.
        private let queue = DispatchQueue(
            label: Constants.DispatchQueues.registryQueue,
            qos: .userInitiated,
            attributes: .concurrent
        )

        /// Token -> weak instance.
        private var instances: [String: WeakUserpilotContainer] = [:]

        /// Insertion order of tokens. Backs deterministic `windowLevel` allocation
        /// via `registrationIndex(forToken:)`. It does **not** affect default
        /// resolution, which is purely claim-based.
        private var registrationOrder: [String] = []

        /// Weak pointer to the instance that opted in via
        /// `Config.defaultInstance(true)` (first claimant wins). This is exactly
        /// what SDK fallback routing uses; the selection is claim-based and so
        /// independent of init order. Because `isDefault` defaults to `true`, the
        /// host app normally holds this from its first `Userpilot(config:)` call.
        ///
        /// Cleared by `unregister(_:)` when the claimant is removed, after which
        /// `default` is `nil` until another instance claims the role.
        private weak var explicitDefaultInstance: Userpilot?

        // MARK: - Init

        /// Use `Registry.shared` instead.
        private init() {}

        // MARK: - Reads

        /// The SDK fallback instance: the one that opted in via
        /// `Config.defaultInstance(true)` (first claimant wins), or `nil` when no
        /// instance currently holds the default role.
        ///
        /// Resolution is purely claim-based and therefore independent of init order
        /// — it survives a vendor SDK initialising before the host. Because
        /// `isDefault` defaults to `true`, a host app that does nothing special is
        /// the default. There is no first-registered fallback: if every live
        /// instance opted out (`defaultInstance(false)`), un-anchored events have no
        /// default to route to and are dropped rather than attributed to an
        /// arbitrary tenant. Returns `nil` before the first init or after the
        /// claimant has been deallocated. Matches the Android registry.
        var `default`: Userpilot? {
            queue.sync { explicitDefaultInstance }
        }

        /// All currently live instances, ignoring deallocated entries.
        var allInstances: [Userpilot] {
            queue.sync { instances.values.compactMap { $0.instance } }
        }

        /// Number of currently live registered instances.
        var liveCount: Int {
            queue.sync { instances.values.compactMap { $0.instance }.count }
        }

        /// Look up an instance by its configured token.
        func instance(forToken token: String) -> Userpilot? {
            queue.sync { instances[token]?.instance }
        }

        /// Returns the deterministic registration index of a token, or `nil` if unknown.
        ///
        /// Used by `ExperienceOverlayWindow` to allocate `windowLevel` so that the
        /// default instance's overlay sits below subsequently registered instances.
        func registrationIndex(forToken token: String) -> Int? {
            queue.sync { registrationOrder.firstIndex(of: token) }
        }

        // MARK: - Writes

        /// Record a fresh `Userpilot` instance and resolve the explicit-default
        /// claim. A pure data-structure mutation: no logging and no autocapture
        /// side effects — the caller (`Userpilot.init`) owns those so the registry
        /// stays free of logger/swizzler dependencies, matching the Android registry.
        ///
        /// `registrationOrder` records the token's position purely for deterministic
        /// `windowLevel` allocation; it has no bearing on default resolution.
        ///
        /// When the instance opted in via `Config.defaultInstance(true)` it claims
        /// the default role if that role is free (or already its own).
        ///
        /// - Returns: the **existing claimant's token** when a later instance tries
        ///   to claim an already-held default role (so the caller can warn the
        ///   integrator); otherwise `nil`.
        @discardableResult
        func register(_ instance: Userpilot) -> String? {
            queue.sync(flags: .barrier) {
                let token = instance.config.token

                instances[token] = WeakUserpilotContainer(instance)
                if !registrationOrder.contains(token) {
                    registrationOrder.append(token)
                }

                guard instance.config.isDefault else { return nil }

                if let current = explicitDefaultInstance, current !== instance {
                    return current.config.token
                }
                explicitDefaultInstance = instance
                return nil
            }
        }

        /// Remove an instance from the registry. Called from `Userpilot.deinit` so
        /// stale weak entries don't pile up across rapid create/destroy cycles.
        func unregister(_ instance: Userpilot) {
            queue.sync(flags: .barrier) {
                let token = instance.config.token
                if instances[token]?.instance === instance {
                    instances.removeValue(forKey: token)
                }
                registrationOrder.removeAll { instances[$0]?.instance == nil }

                // Releasing the default re-opens the role so a future
                // `register(_:)` with `isDefault = true` can claim it. Until then
                // `default` is `nil` (there is no first-registered fallback).
                if explicitDefaultInstance === instance {
                    explicitDefaultInstance = nil
                }
            }
        }

        // MARK: - Test Hooks

        #if DEBUG
        /// Test-only helper: clears every entry. Never call from production code.
        internal func resetForTesting() {
            queue.sync(flags: .barrier) {
                instances.removeAll()
                registrationOrder.removeAll()
                explicitDefaultInstance = nil
            }
        }
        #endif
    }
}
