//
//  InstanceResolver.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `InstanceResolver` decides which registered `Userpilot` instance owns a given
//  swizzled UIKit/SwiftUI hook. With a single instance it resolves to the default
//  instance. With multiple instances it walks the responder chain to the nearest
//  view controller and matches the VC against each instance's claimed scope
//  (VC class > window > bundle), then falls back to the default instance.
//

import UIKit
import os.log

/// Process-wide owner resolver for autocapture events from swizzled hooks. Always
/// reachable through `InstanceResolver.shared`; never instantiated by callers.
internal final class InstanceResolver {

    // MARK: - Shared

    static let shared = InstanceResolver()

    // MARK: - Dependencies

    /// Process-wide instance registry. Injected (with a default of the shared
    /// singleton) so tests can drive routing against a substitute registry
    /// instead of mutating global state.
    private let registry: InstanceRegistering

    init(registry: InstanceRegistering = Userpilot.Registry.shared) {
        self.registry = registry
    }

    // MARK: - One-shot warning state

    /// Lock guarding `didLogNoOwnerDrop`. Plain `NSLock` is enough — this is only
    /// touched on the rare warning path.
    private let warningLock = NSLock()

    /// `true` once the "no owner and no default fallback" warning has been emitted.
    /// Logging once per process keeps the system log clean while still surfacing the issue.
    private var didLogNoOwnerDrop = false

    // MARK: - Target Resolution (public to module)

    /// Resolves the `Userpilot` instance that owns the UI represented by `responder`.
    ///
    /// Returns `nil` only when no instance is registered at all. In multi-instance
    /// integrations where no instance has explicitly claimed the source's scope,
    /// this returns the registered default instance so single-tenant callers
    /// keep working without any client-side change.
    ///
    /// Call sites should use the returned instance's `config` for payload-affecting
    /// flags like `enableInteractionTextCapture` so privacy decisions follow the
    /// correct tenant rather than the (possibly different) default's config.
    func target(forSource responder: UIResponder?) -> Userpilot? {
        return resolveOwningInstance(forResponder: responder)
    }

    /// Like `target(forSource:)` but starting from a specific view controller.
    func target(forViewController viewController: UIViewController?) -> Userpilot? {
        return resolveOwningInstance(forViewController: viewController)
    }

    // MARK: - Resolved Forwarding API

    /// Routes a screen tracking payload from a swizzled view-controller lifecycle hook
    /// to the instance that owns the appearing view controller.
    ///
    /// - Parameters:
    ///   - payload: The screen payload built by the swizzled `viewWillAppear` hook.
    ///   - source: The appearing view controller.
    func trackScreen(_ payload: ScreenTrackingPayload, source: UIViewController?) {
        guard let target = resolveOwningInstance(forViewController: source) else { return }
        guard target.config.enableScreenAutoCapture else { return }
        target.autoCaptureCoordinator.trackScreen(payload)
    }

    /// Suppresses automatic screen capture briefly across every registered instance
    /// after SDK-owned UI has been dismissed. This is a global event rather than a
    /// per-instance one because dismissing any instance's experience can cause
    /// `viewWillAppear` to refire on the underlying app/SDK UI, which any tracker
    /// could otherwise misinterpret as a fresh navigation.
    func suppressScreenAutoCaptureAfterSDKContent() {
        for instance in registry.allInstances {
            // Only forward to instances that actually run screen autocapture; others
            // do not have a coordinator to suppress, and resolving `autoCaptureCoordinator`
            // here would force-init a coordinator we don't need.
            guard instance.config.enableScreenAutoCapture else { continue }
            instance.autoCaptureCoordinator.suppressScreenAutoCaptureAfterSDKContent()
        }
    }

    /// Routes a tab-selection event to the owning instance's tab handler.
    ///
    /// - Parameters:
    ///   - tabName: Selected tab's display name.
    ///   - tabIndex: Selected tab's index.
    ///   - source: The `UITabBarController` whose tab changed.
    func handleTabSelected(name tabName: String, index tabIndex: Int, source: UIResponder?) {
        guard let target = resolveOwningInstance(forResponder: source) else { return }
        guard target.config.enableInteractionAutoCapture else { return }
        // Class of the selected tab's content controller — used as the hierarchy
        // leaf for the published `tab_selected` event (mirrors single-instance path).
        let screenClass = source.map { String(describing: type(of: $0)) } ?? ""
        target.autoCaptureCoordinator.handleTabSelected(
            name: tabName,
            index: tabIndex,
            screenClass: screenClass
        )
    }

    /// Routes a structured interaction payload (control, cell, text input, etc.)
    /// to the owning instance.
    ///
    /// - Parameters:
    ///   - payload: The interaction payload to publish.
    ///   - source: The originating responder (typically the touched view).
    func handleInteractionEvent(_ payload: InteractionPayload, source: UIResponder?) {
        guard let target = resolveOwningInstance(forResponder: source) else { return }
        guard target.config.enableInteractionAutoCapture else { return }
        target.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Routes a window-level click dictionary (built in `UIWindow.swizzleSendEvent`)
    /// to the owning instance.
    ///
    /// - Parameters:
    ///   - properties: Click properties dictionary.
    ///   - source: The originating responder (touched view, or window).
    func handleClickTracked(_ properties: [String: Any], source: UIResponder?) {
        guard let target = resolveOwningInstance(forResponder: source) else { return }
        guard target.config.enableInteractionAutoCapture else { return }
        target.autoCaptureCoordinator.handleClickTracked(properties)
    }
}

// MARK: - Scope Resolution

private extension InstanceResolver {

    /// Returns the `Userpilot` instance that should receive an event originating from `responder`.
    ///
    /// Resolution order:
    /// 1. Walk the responder chain to the nearest `UIViewController`.
    /// 2. If none, treat the responder as a `UIView`/`UIWindow` and resolve via window scope.
    /// 3. If still nothing, fall back to the registered default instance.
    /// 4. If there is no default, drop the event and log a one-shot warning.
    func resolveOwningInstance(forResponder responder: UIResponder?) -> Userpilot? {
        guard let responder = responder else { return defaultOrNil() }

        if let viewController = enclosingViewController(of: responder) {
            return resolveOwningInstance(forViewController: viewController)
        }

        if let window = responder as? UIWindow {
            return resolveOwningInstance(forWindow: window) ?? defaultOrNil()
        }

        if let view = responder as? UIView, let window = view.window {
            return resolveOwningInstance(forWindow: window) ?? defaultOrNil()
        }

        return defaultOrNil()
    }

    /// Returns the `Userpilot` instance that owns `viewController`, applying the
    /// most-specific-match-wins rule (VC class > window > bundle) and walking
    /// outward through SwiftUI hosting controllers when no inner match is found.
    func resolveOwningInstance(forViewController viewController: UIViewController?) -> Userpilot? {
        guard let viewController = viewController else { return defaultOrNil() }

        let candidates = registry.allInstances
        guard !candidates.isEmpty else { return defaultOrNil() }
        if candidates.count == 1 { return candidates[0] }

        var current: UIViewController? = viewController
        while let cursor = current {
            if let match = match(viewController: cursor, against: candidates) {
                return match
            }

            // SwiftUI sometimes wraps the user's view in `UIHostingController<…>`,
            // which lives in SwiftUI's own bundle. Walk outward to the parent VC
            // (which may be a custom container or another hosting VC) so we can
            // still find a VC whose class lives in a claimed bundle.
            if shouldContinueOutward(from: cursor) {
                current = cursor.parent
                continue
            }

            break
        }

        return defaultOrNil()
    }

    /// Returns the instance that owns `window`, or `nil` if no instance claims it.
    func resolveOwningInstance(forWindow window: UIWindow) -> Userpilot? {
        for candidate in registry.allInstances
            where candidate.config.attachedWindows.contains(window) {
            return candidate
        }
        if let rootViewController = window.rootViewController {
            return resolveOwningInstance(forViewController: rootViewController)
        }
        return nil
    }

    /// Tries the (VC class, window, bundle) tests on `viewController` against `candidates`.
    func match(viewController: UIViewController, against candidates: [Userpilot]) -> Userpilot? {
        // 1. VC class match (subclass-aware).
        for candidate in candidates {
            for claimedClass in candidate.config.attachedViewControllerClasses
                where viewController.isKind(of: claimedClass) {
                return candidate
            }
        }

        // 2. Window match.
        if let window = viewController.viewIfLoaded?.window {
            for candidate in candidates
                where candidate.config.attachedWindows.contains(window) {
                return candidate
            }
        }

        // 3. Bundle identifier match.
        if let bundleIdentifier = Bundle(for: type(of: viewController)).bundleIdentifier,
           !bundleIdentifier.isEmpty {
            for candidate in candidates
                where candidate.config.attachedBundleIdentifiers.contains(bundleIdentifier) {
                return candidate
            }
        }

        return nil
    }

    /// Whether to keep walking up `viewController.parent` looking for a claimed scope.
    ///
    /// We always walk outward through `UIHostingController` (SwiftUI hosting VC) since
    /// its bundle is `com.apple.SwiftUI` and never owned by a customer's Userpilot
    /// instance. We also walk through generic `UINavigationController` /
    /// `UITabBarController` containers for the same reason.
    func shouldContinueOutward(from viewController: UIViewController) -> Bool {
        let className = String(describing: type(of: viewController))
        if className.contains("HostingController") { return true }
        if className.contains("HostingViewController") { return true }
        if viewController is UINavigationController { return true }
        if viewController is UITabBarController { return true }
        return false
    }

    /// Walks the responder chain to find the enclosing `UIViewController`, if any.
    func enclosingViewController(of responder: UIResponder) -> UIViewController? {
        var current: UIResponder? = responder
        while let cursor = current {
            if let viewController = cursor as? UIViewController { return viewController }
            current = cursor.next
        }
        return nil
    }

    /// Returns the default instance (the `isDefault` claimant), or `nil` while
    /// logging a one-shot warning when no instance holds the default role.
    ///
    /// In the unified single-rule routing model, un-anchored events fall back to
    /// the default just like single-tenant events do. `nil` is returned when the
    /// SDK has not been initialized, or when every live instance opted out of the
    /// default role (`defaultInstance(false)`).
    func defaultOrNil() -> Userpilot? {
        if let target = registry.default { return target }

        warningLock.lock()
        let alreadyLogged = didLogNoOwnerDrop
        didLogNoOwnerDrop = true
        warningLock.unlock()

        if !alreadyLogged {
            // No registered default means no logger to call. Use the system log directly.
            // This fires once when an autocapture hook fires before any
            // `Userpilot(config:)` has run.
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
