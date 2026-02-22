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

/// Extension providing automatic click tracking for UIWindow
extension UIWindow {

    // MARK: - Static Methods

    /// Swizzles sendEvent method to intercept touch events
    static func swizzleSendEvent() {
        guard self === UIWindow.self else { return }

        Swizzler.swapInstanceMethods(
            on: self,
            original: #selector(sendEvent(_:)),
            swizzled: #selector(swizzled_sendEvent(_:))
        )
    }

    /// Swizzled sendEvent that intercepts and processes touch events
    /// - Parameter event: The UI event to process
    @objc func swizzled_sendEvent(_ event: UIEvent) {
        self.swizzled_sendEvent(event)  // calls original sendEvent

        // Check if SDK is initialized
        guard Userpilot.isInitialized else { return }

        guard let touches = event.allTouches else { return }
        for touch in touches where touch.phase == .began {
            guard let touchedView = touch.view else { continue }

            // Resolve the deepest subview at the touch point.
            // UILabel / UIImageView have isUserInteractionEnabled = false,
            // so touch.view returns their parent. We walk into the hierarchy
            // ourselves to find the real visual element the user tapped on.
            let locationInWindow = touch.location(in: self)
            let resolvedView = deepestSubview(at: locationInWindow, in: touchedView) ?? touchedView

            handleTouchOnView(resolvedView)
        }
    }

    // MARK: - Private Methods

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

    /// Routes touch handling based on the view type
    /// - Parameter view: The UIView that was touched (already resolved to deepest subview)
    private func handleTouchOnView(_ view: UIView) {
        let config = Userpilot.shared.config
        guard config.enableInteractionAutocapture else { return }

        // 1. Skip UIControl subclasses (handled by UIControl.sendAction swizzling)
        //    EXCEPT: don't skip UITextField — text input is handled by notifications
        if view is UIControl && !(view is UITextField) {
            return
        }

        // Skip views inside a UIControl (like UIButton's internal UILabel/UIImageView)
        // But allow views inside UITextField to pass through
        if let parentControl = findParentControl(for: view),
           !(parentControl is UITextField) {
            return
        }

        // 2. Check for UITableViewCell
        if let tableCell = findParentTableViewCell(for: view) {
            tableCell.captureTableViewCellSelection(touchedView: view)
            return
        }

        // 3. Check for UICollectionViewCell
        if let collectionCell = findParentCollectionViewCell(for: view) {
            collectionCell.captureCollectionViewItemSelection(touchedView: view)
            return
        }

        // 4. Handle regular view tap (UILabel, UIImageView, UITextView, plain UIView, etc.)
        handleRegularViewTap(on: view, config: config)
    }

    /// Handles tap on regular views (not controls, table cells, or collection cells)
    private func handleRegularViewTap(on view: UIView, config: Userpilot.Config) {
        guard !view.shouldIgnoreInteractions() else { return }

        var eventProperties: [String: Any] = [
            "interaction_type": InteractionType.tap.rawValue,
            "auto_capture_source": FrameworkType.uiKit.rawValue,
            "element_type": String(describing: type(of: view)),
            "element_path": UIKitViewResolver.resolvePath(view: view)
        ]

        if let accessibilityIdentifier = view.accessibilityIdentifier, !accessibilityIdentifier.isEmpty {
            eventProperties["accessibility_identifier"] = accessibilityIdentifier
        }

        if !config.disableInteractionAccessibilityLabelCapture {
            if let accessibilityLabel = view.getAccessibilityLabelContent() {
                eventProperties["accessibility_label"] = accessibilityLabel
            }
        }

        if !config.disableInteractionTextCapture {
            if let text = view.getTextContent() {
                eventProperties["element_text"] = text
            }
        }

        Userpilot.shared.uiKitAutoCaptureEngine.handleClickTracked(eventProperties)
    }

    // MARK: - View Hierarchy Helpers

    /// Finds a parent UIControl in the view hierarchy
    private func findParentControl(for view: UIView) -> UIControl? {
        var currentView: UIView? = view.superview
        while let parent = currentView {
            if let control = parent as? UIControl {
                return control
            }
            currentView = parent.superview
        }
        return nil
    }

    /// Finds a parent UITableViewCell in the view hierarchy
    private func findParentTableViewCell(for view: UIView) -> UITableViewCell? {
        var currentView: UIView? = view
        while let current = currentView {
            if let cell = current as? UITableViewCell {
                return cell
            }
            currentView = current.superview
        }
        return nil
    }

    /// Finds a parent UICollectionViewCell in the view hierarchy
    private func findParentCollectionViewCell(for view: UIView) -> UICollectionViewCell? {
        var currentView: UIView? = view
        while let current = currentView {
            if let cell = current as? UICollectionViewCell {
                return cell
            }
            currentView = current.superview
        }
        return nil
    }
}
