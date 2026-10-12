//
//  InstanceResolver.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/06/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves native UI ownership from the nearest explicit binding, configured
//  controller/window/bundle scopes, then the registered default. Publication
//  and capture gates remain with the selected instance's coordinator.
//

import UIKit
import os.log

/// Reads UI ownership without publishing events or retaining native sources.
internal protocol InstanceResolving: AnyObject {
    /// `false` while no binding or configured scope exists; every source then resolves to the default.
    var sourceAffectsOwner: Bool { get }
    func resolveOwner(from responder: UIResponder?) -> Userpilot?
}

/// Runtime-owned policy shared by UIKit hooks and SwiftUI's native capture bridge.
internal final class InstanceResolver: InstanceResolving {

    private let registry: InstanceRegistering

    /// Keeps the existing no-owner diagnostic to one message for this runtime.
    private let didLogNoOwnerDrop = AtomicReference<Bool>(false)

    init(registry: InstanceRegistering) {
        self.registry = registry
    }

    var sourceAffectsOwner: Bool { !canOnlyResolveToDefault }

    /// Resolves once at admission. Disabled owners still own their UI; the coordinator
    /// drops their events. A removed explicit owner blocks fallback to another tenant.
    func resolveOwner(from responder: UIResponder?) -> Userpilot? {
        // Without bindings or configured claims every path below ends at the default, so the
        // per-event responder and scope walks are skipped on this hot path.
        guard let responder, !canOnlyResolveToDefault else { return defaultOrNil() }

        if let binding = responder.userpilotOwnerBindingInHierarchy {
            guard let owner = binding.owner, registry.isRegistered(owner) else { return nil }
            return owner.canonicalInstance
        }

        if let viewController = responder.instanceResolutionViewController {
            return resolveScopeOwner(for: viewController) ?? defaultOrNil()
        }

        if let window = (responder as? UIWindow) ?? (responder as? UIView)?.window {
            if let owner = registry.allInstances.first(where: { $0.config.attachedWindows.contains(window) }) {
                return owner
            }
            if let root = window.rootViewController {
                return resolveOwner(from: root)
            }
        }

        return defaultOrNil()
    }
}

// MARK: - Configured scopes

private extension InstanceResolver {

    /// Only explicit bindings and configured scopes can route a source away from the default.
    var canOnlyResolveToDefault: Bool {
        !UserpilotOwnerBinding.hasAttachments.value
            && !registry.allInstances.contains { $0.config.hasOwnershipClaims }
    }

    /// Preserves class > window > bundle precedence and the existing outward walk
    /// through SwiftUI hosting controllers. Instance count never bypasses claims.
    func resolveScopeOwner(for viewController: UIViewController) -> Userpilot? {
        let candidates = registry.allInstances
        var current: UIViewController? = viewController
        while let cursor = current {
            if let owner = match(viewController: cursor, against: candidates) {
                return owner
            }

            // Hosting controllers belong to SwiftUI's bundle. Continue to their parent
            // so an embedded SDK can claim its own containing controller or bundle.
            guard cursor.continuesOutwardInstanceResolution else { break }
            current = cursor.parent
        }
        return nil
    }

    /// Applies the established specificity order; registry order settles equal claims.
    func match(viewController: UIViewController, against candidates: [Userpilot]) -> Userpilot? {
        for candidate in candidates {
            for claimedClass in candidate.config.attachedViewControllerClasses
                where viewController.isKind(of: claimedClass) {
                return candidate
            }
        }

        if let window = viewController.viewIfLoaded?.window {
            for candidate in candidates where candidate.config.attachedWindows.contains(window) {
                return candidate
            }
        }

        if let bundleIdentifier = Bundle(for: type(of: viewController)).bundleIdentifier,
           !bundleIdentifier.isEmpty {
            for candidate in candidates where candidate.config.attachedBundleIdentifiers.contains(bundleIdentifier) {
                return candidate
            }
        }
        return nil
    }

    /// An unclaimed source belongs only to the explicit default, never to an
    /// arbitrary sole instance. Preserve the existing one-shot diagnostic format.
    func defaultOrNil() -> Userpilot? {
        if let owner = registry.default { return owner }
        if !didLogNoOwnerDrop.getAndSet(true) {
            let log = OSLog(userpilotCategory: UserpilotLogging.general)
            os_log(
                "⚠️ Userpilot autocapture event dropped: SDK has not been initialized.",
                log: log,
                type: .info
            )
        }
        return nil
    }
}

private extension Userpilot.Config {
    /// Conservative: a weak window table may still count a released window, which only
    /// keeps the full resolution path.
    var hasOwnershipClaims: Bool {
        !attachedViewControllerClasses.isEmpty || attachedWindows.count > 0 || !attachedBundleIdentifiers.isEmpty
    }
}
