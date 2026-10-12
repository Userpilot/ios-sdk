//
//  UIWindow+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  UIWindow+Extensions implements automatic click tracking by intercepting touch events
//  at the window level, providing comprehensive analytics capture for both UIKit and SwiftUI.
//

import UIKit

// MARK: - Public

@objc
public extension UIWindow {
    /// `true` when this window is an internal Userpilot SDK overlay.
    ///
    /// Useful from screen-capture / analytics integrations that need to skip
    /// SDK-owned UI when walking the application's window list. Also used
    /// internally by `ExperienceOverlayWindow`'s scene resolver to avoid
    /// picking its own scene as the fallback host.
    var isUserpilotWindow: Bool {
        return self is ExperienceOverlayWindow
    }
}

/// Touch starts for tap-end click capture (see `SwiftUITitleCapturePolicy.capturesClicksOnTapEnd`).
/// `sendEvent` runs on main, so the shared tracker is main-confined.
private enum WindowTapCapture {
    static let tracker = WindowTapTracker()
}

// MARK: - Internal

/// Extension providing automatic click tracking for UIWindow
extension UIWindow {

    // MARK: Setup

    /// Swizzles sendEvent method to intercept touch events
    static func swizzleSendEvent() {
        guard self === UIWindow.self else { return }

        Swizzler.swapInstanceMethods(
            on: self,
            original: #selector(sendEvent(_:)),
            swizzled: #selector(swizzled_sendEvent(_:))
        )
    }

    // MARK: Event Handling

    /// Swizzled sendEvent that intercepts and processes touch events
    /// - Parameter event: The UI event to process
    @objc func swizzled_sendEvent(_ event: UIEvent) {
        self.swizzled_sendEvent(event)  // calls original sendEvent

        // Keep bookkeeping for every touch so ending/cancelled sequences retire even
        // while an owner is stopped. Paused owners skip native capture and scan work;
        // their coordinator also guards publication.
        guard let touches = event.allTouches else { return }
        let resolver = UserpilotRuntime.shared.instanceResolver
        var scanOwner: Userpilot?
        for touch in touches {
            let point = touch.location(in: self)
            let hitView = touch.view ?? hitTest(point, with: event)
            let source = touchOwnerSource(hitView: hitView, at: point, phase: touch.phase, resolver: resolver)
            guard let target = resolver.resolveOwner(from: source.view) else { continue }
            let config = target.config
            // The touched view's owner controls timing, just as it controls text/privacy flags.
            if WindowTapCapture.tracker.shouldCapture(
                touch,
                phase: touch.phase,
                at: point,
                timestamp: touch.timestamp,
                touchCount: touches.count,
                capturesOnTapEnd: SwiftUITitleCapturePolicy.capturesClicksOnTapEnd(config)
            ), let hitView, !target.autoCaptureCoordinator.isStopped {
                let capturedView = capturedTapView(hitView: hitView, source: source, at: point)
                handleTouchOnView(capturedView, target: target, window: self, point: point)
            }
            if scanOwner == nil, touch.phase == .ended || touch.phase == .cancelled,
               SwiftUITitleCapturePolicy.shouldRun(for: target, isSwiftUIHost: source.view.up_isInsideHostingView) {
                scanOwner = target
            }
        }
        // Touch settle refreshes lazy content revealed by scrolling, once per native event.
        if let scanOwner {
            UserpilotRuntime.shared.scanCache.scheduleRescan(reason: .touchEnded, window: self, owner: scanOwner)
        }
    }

    // MARK: Touch Routing

    /// A nested owner on a descendant can affect click timing, so tap boundaries resolve
    /// from the innermost view, but only when a binding or configured scope exists.
    func touchOwnerSource(
        hitView: UIView?, at point: CGPoint, phase: UITouch.Phase, resolver: InstanceResolving
    ) -> (view: UIView, isInnermost: Bool) {
        let resolvesFromInnermost = (phase == .began || phase == .ended) && resolver.sourceAffectsOwner
        let view = hitView.map {
            resolvesFromInnermost ? deepestSubview(at: point, in: $0) ?? $0 : $0
        } ?? self
        return (view, resolvesFromInnermost)
    }

    /// The payload always describes the innermost view; compute it only for a captured tap.
    func capturedTapView(hitView: UIView, source: (view: UIView, isInnermost: Bool), at point: CGPoint) -> UIView {
        source.isInnermost ? source.view : deepestSubview(at: point, in: hitView) ?? hitView
    }

    /// Finds the deepest (front-most) subview whose frame contains `point`,
    /// ignoring `isUserInteractionEnabled` so we can discover UILabel / UIImageView.
    private func deepestSubview(at point: CGPoint, in root: UIView) -> UIView? {
        // Convert the point into the root view's coordinate space
        let localPoint = root.convert(point, from: self)

        // Walk subviews in reverse (front-most first)
        for subview in root.subviews.reversed() {
            // Skip hidden / transparent views
            guard !subview.isHidden, subview.alpha > 0.01 else { continue }

            let subviewPoint = subview.convert(point, from: self)
            guard subview.bounds.contains(subviewPoint) else { continue }

            // Recurse into this subview
            if let deeper = deepestSubview(at: point, in: subview) {
                return deeper
            }

            // This subview itself is the deepest at this point
            return subview
        }

        // No subviews matched — the root itself is the deepest
        guard root.bounds.contains(localPoint) else { return nil }
        return root
    }

    /// `true` when the touch is on scrollable list “background” (not a row/item), e.g. empty space
    /// below the last `UITableView` row. Cells and section/table header/footer are excluded.
    private func isTouchOnScrollableListEmptyChrome(_ view: UIView) -> Bool {
        isTouchOnTableViewEmptyChrome(view) || isTouchOnCollectionViewEmptyChrome(view)
    }

    private func isTouchOnTableViewEmptyChrome(_ view: UIView) -> Bool {
        guard let tableView = view.findAncestorUITableView() else { return false }
        if view.findParentTableViewCell() != nil { return false }
        if view.findParentTableViewHeaderFooter() != nil { return false }
        if let header = tableView.tableHeaderView, view.isDescendant(of: header) { return false }
        if let footer = tableView.tableFooterView, view.isDescendant(of: footer) { return false }
        return true
    }

    private func isTouchOnCollectionViewEmptyChrome(_ view: UIView) -> Bool {
        guard view.findAncestorUICollectionView() != nil else { return false }
        if view.findParentCollectionViewCell() != nil { return false }
        if view.findParentCollectionReusableView() != nil { return false }
        return true
    }

    /// Routes touch handling based on the view type (table/collection cells, controls, or regular tap)
    /// - Parameters:
    ///   - view: The UIView that was touched (already resolved to deepest subview)
    ///   - window: The window where the touch occurred
    ///   - point: Touch location in window coordinates
    private func handleTouchOnView(_ view: UIView, target: Userpilot, window: UIWindow, point: CGPoint) {
        // Continue with the owner selected at the native touch boundary.
        let config = target.config
        guard config.enableInteractionAutoCapture else { return }

        // 1. Skip UIControl subclasses (handled by UIControl.sendAction swizzling)
        //    EXCEPT: don't skip UITextField — text input is handled by notifications
        if view is UIControl && !(view is UITextField) {
            return
        }

        // Skip views inside a UIControl (like UIButton's internal UILabel/UIImageView)
        // But allow views inside UITextField to pass through
        if let parentControl = view.findParentControl(),
           !(parentControl is UITextField) {
            return
        }

        // 2. Check for UITableViewCell
        //    Skip cells that live inside a UIPickerView (e.g. SwiftUI's `.pickerStyle(.wheel)`
        //    backs onto `UIKitPickerView → UIPickerView → UIPickerTableView →
        //    UIPickerTableViewWrapperCell`). The picker view's delegate hook will emit the
        //    canonical `picker_view_changed` event for the same gesture, and we don't want a
        //    duplicate `table_view_cell_selected` from the picker's internal table.
        if let tableCell = view.findParentTableViewCell() {
            if tableCell.findAncestorUIPickerView() != nil {
                return
            }
            tableCell.captureTableViewCellSelection(touchedView: view, owner: target)
            return
        }

        // 3. Check for UICollectionViewCell
        if let collectionCell = view.findParentCollectionViewCell() {
            collectionCell.captureCollectionViewItemSelection(touchedView: view, owner: target)
            return
        }

        // 3b. Skip empty chrome of table/collection scroll areas (below last row, wrapper, etc.).
        if isTouchOnScrollableListEmptyChrome(view) {
            return
        }

        // 3c. Direct hit on a plain `UIScrollView` (not table/collection) — usually chrome, not content.
        if type(of: view) == UIScrollView.self {
            return
        }

        // 4. Handle regular view tap (UILabel, UIImageView, UITextView, plain UIView, etc.)
        handleRegularViewTap(on: view, target: target, window: window, point: point)
    }

    // MARK: View Tap Handling

    /// Handles tap on regular views (not controls, table cells, or collection cells)
    internal func handleRegularViewTap(
        on view: UIView,
        target: Userpilot,
        window: UIWindow,
        point: CGPoint
    ) {
        guard !target.autoCaptureCoordinator.isStopped, !view.shouldIgnoreInteractions() else { return }
        let config = target.config

        // SwiftUI button autocapture (opt-in, iOS 26+) only changes taps inside SwiftUI content.
        let isSwiftUIButtonTap = SwiftUITitleCapturePolicy.isFeatureEnabled(config) && view.up_isInsideHostingView
        // SwiftUI's ignore carrier may be a sibling of the hit view. Reject the entire
        // interaction before reading metadata, even when UIKit already supplies a title or identifier.
        if isSwiftUIButtonTap,
           view.up_outermostHostingView.up_flagInSubtree(containing: point, \.userpilotIgnoreInteractions) {
            return
        }
        var eventProperties = view.buildWindowInteractionProperties(
            at: point,
            in: window,
            limitsTextToTapPoint: isSwiftUIButtonTap
        )
        var resolvedSwiftUIControl = false
        if isSwiftUIButtonTap {
            resolvedSwiftUIControl = view.addSwiftUITitle(
                to: &eventProperties, at: point, in: window, owner: target
            )
        }

        target.autoCaptureCoordinator.handleClickTracked(
            eventProperties, resolvedSwiftUIControl: resolvedSwiftUIControl
        )
    }

}
