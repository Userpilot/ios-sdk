//
//  UIWindow+Extensions.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
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
        return self is ExperienceOverlayWindow || self is DebugUIWindow
    }
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

        // No global stop check here: this is touch bookkeeping shared by all
        // instances. Per-instance pausing is enforced downstream when the captured
        // touch is published through the owning instance's coordinator.
        guard Userpilot.isInitialized else { return }

        guard let touches = event.allTouches else { return }
        for touch in touches where touch.phase == .began {
            let locationInWindow = touch.location(in: self)
            // SwiftUI often leaves touch.view nil; fall back to hit-testing the window.
            let touchedView = touch.view ?? self.hitTest(locationInWindow, with: event)
            guard let view = touchedView else { continue }

            let resolvedView = deepestSubview(at: locationInWindow, in: view) ?? view

            handleTouchOnView(resolvedView, window: self, point: locationInWindow, event: event)
        }
    }

    // MARK: Touch Routing

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
    ///   - event: The UI event
    private func handleTouchOnView(_ view: UIView, window: UIWindow, point: CGPoint, event: UIEvent) {
        // Resolve the owning Userpilot instance for this view so its config drives
        // privacy and capture decisions (text/value/accessibility flags). In a
        // single-instance integration this is the default instance, identical to
        // the previous global fallback config behaviour.
        guard let target = InstanceResolver.shared.target(forSource: view) else { return }
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
            tableCell.captureTableViewCellSelection(touchedView: view)
            return
        }

        // 3. Check for UICollectionViewCell
        if let collectionCell = view.findParentCollectionViewCell() {
            collectionCell.captureCollectionViewItemSelection(touchedView: view)
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
        handleRegularViewTap(on: view, config: config, window: window, point: point, event: event)
    }

    // MARK: View Tap Handling

    /// Handles tap on regular views (not controls, table cells, or collection cells)
    private func handleRegularViewTap(
        on view: UIView,
        config: Userpilot.Config,
        window: UIWindow,
        point: CGPoint,
        event: UIEvent
    ) {
        guard !view.shouldIgnoreInteractions() else { return }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: view)
        let useRedactedInner = (effectiveView !== view)

        var eventProperties: [String: Any] = [
            AutoCaptureConstants.targetClass: String(describing: type(of: effectiveView)),
            AutoCaptureConstants.hierarchy: path
        ]

        if let capture = view.resolveUserpilotLabelCapture(atWindowPoint: point, in: window) {
            if let labelViewType = capture.viewType {
                eventProperties[AutoCaptureConstants.targetClass] = labelViewType
            }
            eventProperties[AutoCaptureConstants.targetText] = capture.labeledView.shouldRedactText()
                ? AutoCaptureConstants.reductText
                : capture.label
        } else if useRedactedInner {
            eventProperties[AutoCaptureConstants.targetText] = AutoCaptureConstants.reductText
        } else {
            if let accessibilityIdentifier = view.accessibilityIdentifier, !accessibilityIdentifier.isEmpty {
                eventProperties[AutoCaptureConstants.accessibilityIdentifier] = accessibilityIdentifier
            }
            if let accessibilityLabel = view.getAccessibilityLabelContent() {
                eventProperties[AutoCaptureConstants.accessibilityLabel] = accessibilityLabel
            }
            if let text = view.getTextContent() {
                eventProperties[AutoCaptureConstants.targetText] = text
            }
        }

        InstanceResolver.shared.handleClickTracked(eventProperties, source: view)
    }

}
