//
//  ExperienceOverlayWindow.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Per-Userpilot-instance `UIWindow` used to host experience presentations
//  (dialog, bottom sheet, slide-out, NPS, survey). Each instance gets its own
//  overlay so multiple instances may render experiences concurrently without
//  fighting over the host app's `keyWindow`. Touches outside any experience
//  subview fall through via passthrough hit-testing so the underlying app and
//  any other instance's overlay window remain fully interactive.
//

import UIKit

/// `UIWindow` subclass that hosts experience UI for one `Userpilot` instance.
///
/// Single-instance behaviour: indistinguishable from the previous `keyWindow`
/// presentation path because the overlay window covers the whole screen at
/// `windowLevel.normal + 1` and forwards every non-experience hit through to
/// the underlying app window.
///
/// Multi-instance behaviour: each registered instance gets its own overlay at a
/// deterministic `windowLevel`, so two experiences may be visible simultaneously
/// (the higher level draws on top), and each remains independently interactive.
internal final class ExperienceOverlayWindow: UIWindow {

    // MARK: - State

    /// The `Userpilot` instance that owns this overlay. Held weakly so
    /// destroying the instance also releases the window.
    private weak var owningInstance: Userpilot?

    // MARK: - Initialization

    /// Initialises the overlay attached to a foreground-active scene (preferred)
    /// or, as a fallback, to the scene of any existing non-Userpilot window in
    /// the application. The window is made visible synchronously so its root
    /// view controller is in the window hierarchy by the time the caller
    /// presents on it — without this, UIKit warns "view is not in the window
    /// hierarchy" and the present silently drops.
    ///
    /// The fallback path matters during state transitions (early launch,
    /// app-coming-to-foreground, multitasking handoff) when
    /// `activeWindowScenes.first` is briefly empty.
    init(owningInstance: Userpilot) {
        self.owningInstance = owningInstance

        if let scene = Self.resolveScene() {
            super.init(windowScene: scene)
            // `UIWindow(windowScene:)` leaves `frame = .zero`. An empty frame
            // makes the rootViewController's view never become visible even
            // after `isHidden = false`, which triggers the UIKit
            // "view is not in the window hierarchy" warning at present time.
            self.frame = scene.coordinateSpace.bounds
        } else {
            super.init(frame: UIScreen.main.bounds)
        }

        backgroundColor = .clear
        rootViewController = OverlayPassthroughHostViewController()
        windowLevel = Self.computeWindowLevel(for: owningInstance)

        // Auto-claim this overlay for the owning instance's autocapture scope so
        // taps inside an experience attribute correctly to its tenant.
        owningInstance.config.attach(windows: [self])

        // Surface the window immediately so its rootViewController is part of
        // the scene's window hierarchy from this point onward. Mirrors the
        // pattern used by Appcues' overlay (`AppcuesUIWindow`) — without this,
        // a later `rootViewController.present(...)` from `ExperiencesPublisher`
        // fires before the window is attached and UIKit drops the present
        // with "whose view is not in the window hierarchy".
        isHidden = false
        UPOverlayVisibility.overlayVisibilityMayHaveChanged()

        // Observe scene disconnects so a dead `windowScene` (e.g. the user
        // closes an iPad window or the app drops a split-view scene) is detected
        // and the overlay collapses instead of presenting onto an invalid scene.
        // Recovery happens lazily in `prepareForPresentation()`.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidDisconnect(_:)),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Number of Userpilot overlay windows currently on screen across the whole process.
    ///
    /// Used to suppress Liquid Glass on card surfaces when two or more instances are showing
    /// an experience at once: each instance owns its own overlay window, so two glass cards
    /// would stack into the layered-glass appearance Apple advises against, with neither
    /// instance having chosen it.
    static func visibleWindowCount() -> Int {
        UPOverlayVisibility.visibleCount
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Hit Testing (passthrough)

    /// Lets touches that don't land on any subview of the root view fall through
    /// to the underlying window. Without this, a fully-covered overlay window
    /// would steal every touch even when no experience is being presented.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else { return nil }

        // The overlay's root view itself never claims touches — only its
        // descendants do (the presented experience VC's view tree).
        if result === rootViewController?.view || result === self {
            return nil
        }
        return result
    }

    // MARK: - Presentation

    /// Prepares the overlay for a new presentation.
    ///
    /// `hideIfIdle()` collapses the overlay after dismissal. A later UIKit
    /// presentation on the hidden window can still drive view-controller
    /// lifecycle callbacks, which sends "seen" events while drawing nothing.
    /// Always re-surface the window immediately before presenting content.
    ///
    /// Also re-resolves the hosting scene first: the scene captured at `init`
    /// can become invalid between presentations (iPad multi-window close,
    /// split-view transition, or a scene that was briefly unavailable at launch).
    /// Presenting onto a dead scene makes UIKit silently drop the present, so we
    /// migrate the window to a live scene before surfacing.
    func prepareForPresentation() {
        reattachToActiveSceneIfNeeded()
        if let owner = owningInstance {
            windowLevel = Self.computeWindowLevel(for: owner)
        }
        isHidden = false
        UPOverlayVisibility.overlayVisibilityMayHaveChanged()
    }

    /// Recomputes `windowLevel` so newly-registered sibling tenants (which would
    /// push the registration index forward) still resolve to a stable z-order.
    func refreshWindowLevel() {
        if let owner = owningInstance {
            windowLevel = Self.computeWindowLevel(for: owner)
        }
    }

    /// Hides the overlay once no experience is being presented anymore so it
    /// stops consuming input focus while idle.
    func hideIfIdle() {
        guard rootViewController?.presentedViewController == nil else { return }
        isHidden = true
        UPOverlayVisibility.overlayVisibilityMayHaveChanged()
    }

    // MARK: - Scene Lifecycle

    /// Collapses the overlay when the scene it lives on disconnects (e.g. the
    /// user closes an iPad window or the app drops a split-view scene).
    ///
    /// The window object survives because the owning instance retains it, but
    /// its `windowScene` is now dead. We only hide here; the next
    /// `prepareForPresentation()` re-resolves a live scene via
    /// `reattachToActiveSceneIfNeeded()` before the overlay is shown again.
    @objc private func sceneDidDisconnect(_ note: Notification) {
        guard let disconnected = note.object as? UIWindowScene,
              disconnected === windowScene else { return }
        isHidden = true
        UPOverlayVisibility.overlayVisibilityMayHaveChanged()
    }

    // MARK: - Window Level

    /// Computes a deterministic `UIWindow.Level` for `instance` based on its
    /// registration order in `Userpilot.Registry`. Default instance sits at
    /// `normal + 1`, secondaries stack above it.
    private static func computeWindowLevel(for instance: Userpilot) -> UIWindow.Level {
        let token = instance.config.token
        let index = Userpilot.Registry.shared.registrationIndex(forToken: token) ?? 0
        // `+ 1` keeps the overlay above ordinary app windows; `+ index` separates
        // multiple instances so two experiences never collide on the same level.
        return UIWindow.Level.normal + CGFloat(1 + index)
    }

    // MARK: - Scene Resolution

    /// Picks the best `UIWindowScene` to attach the overlay to.
    ///
    /// Preference order:
    /// 1. Any foreground-active scene (the common case at present time).
    /// 2. The scene hosting an existing non-Userpilot window — covers state
    ///    transitions where no scene is `foregroundActive` yet but the host
    ///    app's main window scene is still reachable.
    ///
    /// Returns `nil` only when neither path resolves a scene; callers fall
    /// through to the legacy `UIScreen.main.bounds` init path. Mirrors
    /// Appcues' `mainWindowScene` resolver.
    private static func resolveScene() -> UIWindowScene? {
        if let active = UIApplication.shared.activeWindowScenes.first {
            return active
        }
        return UIApplication.shared.windows
            .first(where: { !$0.isUserpilotWindow })?
            .windowScene
    }

    /// Migrates the overlay to a currently-active scene when the scene captured
    /// at `init` is no longer usable.
    ///
    /// `UIWindow.windowScene` is settable on iOS 13+, so we move the existing
    /// window to a fresh scene in place instead of destroying and recreating it.
    /// This is cheaper and preserves the window's identity — its autocapture
    /// claim (`config.attach(windows:)`), root view controller, and computed
    /// `windowLevel` all survive the migration.
    ///
    /// The current scene is considered unusable when it is `nil` (already
    /// released after a disconnect) or no longer present in
    /// `connectedScenes` (disconnected / unattached). When no live scene can be
    /// resolved the window is left as-is; the caller still surfaces it and a
    /// later presentation retries.
    private func reattachToActiveSceneIfNeeded() {
        let currentSceneIsUsable: Bool = {
            guard let scene = windowScene else { return false }
            return UIApplication.shared.connectedScenes.contains(scene)
        }()

        guard !currentSceneIsUsable, let freshScene = Self.resolveScene() else { return }

        windowScene = freshScene
        // `UIWindow(windowScene:)` / a scene swap can leave `frame = .zero`,
        // which keeps the rootViewController's view from ever becoming visible.
        // Re-sync the frame to the new scene's bounds (mirrors `init`).
        frame = freshScene.coordinateSpace.bounds
    }
}

// MARK: - Passthrough Host VC

/// Trivial root view controller for the overlay window. Its only job is to host
/// presented experience VCs; it never draws content of its own.
private final class OverlayPassthroughHostViewController: UIViewController {

    override func loadView() {
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )

        let view = PassthroughView()
        view.backgroundColor = .clear
        self.view = view
    }

    override var prefersStatusBarHidden: Bool {
        // Defer to the underlying app's status bar style/visibility. The
        // overlay window covers the whole screen so without this a presented
        // experience could accidentally hide / change the status bar.
        return false
    }
}

/// `UIView` subclass whose own area never claims touches; only its subviews can.
/// Used as the root view of `OverlayPassthroughHostViewController`.
private final class PassthroughView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        // If the only thing the touch landed on is *this* view, treat as a miss
        // so the touch falls through to the underlying window.
        if result === self { return nil }
        return result
    }
}
