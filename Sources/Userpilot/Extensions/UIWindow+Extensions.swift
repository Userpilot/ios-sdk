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

        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        guard Userpilot.isInitialized else { return }

        guard let touches = event.allTouches else { return }
        for touch in touches where touch.phase == .began {
            let locationInWindow = touch.location(in: self)
            // SwiftUI often leaves touch.view nil; fall back to hit-testing the window.
            let touchedView = touch.view ?? self.hitTest(locationInWindow, with: event)
            guard let view = touchedView else { continue }

            let resolvedView = deepestSubview(at: locationInWindow, in: view) ?? view

            if Userpilot.shared.config.appFramework == .SwiftUI {
                handleSwiftUIClick(at: locationInWindow, event: event, view: resolvedView)
            } else {
                handleTouchOnView(resolvedView, window: self, point: locationInWindow, event: event)
            }
        }
    }

    // MARK: SwiftUI Click

    /// Handles SwiftUI click tracking at the given point; sends event through the UIKit engine pipeline.
    /// - Parameters:
    ///   - point: The touch point in window coordinates
    ///   - event: The UI event
    ///   - view: The UIView that was touched (resolved to deepest subview)
    private func handleSwiftUIClick(at point: CGPoint, event: UIEvent, view: UIView) {
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }
        guard !view.shouldIgnoreInteractions() else { return }
        // Prefer UIKit event for navigation bar (e.g. back button) to avoid duplicate SwiftUI + UIKit events
        if config.preferUIKitOverSwiftUIForNavigationBar, view.isInsideNavigationBar {
            return
        }

        let swiftUIProperties =
            SwiftUIViewResolver.resolveClickProperties(
                window: self,
                point: point,
                event: event,
                fallbackView: view
            ) ?? [:]
        Userpilot.shared.autoCaptureEngine.handleClickTracked(swiftUIProperties)
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

    /// Routes touch handling based on the view type (table/collection cells, controls, or regular tap)
    /// - Parameters:
    ///   - view: The UIView that was touched (already resolved to deepest subview)
    ///   - window: The window where the touch occurred
    ///   - point: Touch location in window coordinates
    ///   - event: The UI event
    private func handleTouchOnView(_ view: UIView, window: UIWindow, point: CGPoint, event: UIEvent) {
        let config = Userpilot.shared.config
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
        if let tableCell = view.findParentTableViewCell() {
            tableCell.captureTableViewCellSelection(touchedView: view)
            return
        }

        // 3. Check for UICollectionViewCell
        if let collectionCell = view.findParentCollectionViewCell() {
            collectionCell.captureCollectionViewItemSelection(touchedView: view)
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

        if config.appFramework == .SwiftUI,
           let swiftUIProperties = SwiftUIViewResolver.resolveClickProperties(
               window: window,
               point: point,
               event: event,
               fallbackView: view
           ) {
            Userpilot.shared.autoCaptureEngine.handleClickTracked(swiftUIProperties)
            return
        }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: view)
        let useRedactedInner = (effectiveView !== view)

        var eventProperties: [String: Any] = [
            AutoCaptureConstants.elementType: String(describing: type(of: effectiveView)),
            AutoCaptureConstants.hierarchy: path
        ]

        if useRedactedInner {
            eventProperties[AutoCaptureConstants.elementText] = AutoCaptureConstants.reductText
        } else {
            if let accessibilityIdentifier = view.accessibilityIdentifier, !accessibilityIdentifier.isEmpty {
                eventProperties[AutoCaptureConstants.accessibilityIdentifier] = accessibilityIdentifier
            }
            if let accessibilityLabel = view.getAccessibilityLabelContent() {
                eventProperties[AutoCaptureConstants.accessibilityLabel] = accessibilityLabel
            }
            if let text = view.getTextContent() {
                eventProperties[AutoCaptureConstants.elementText] = text
            }
        }

        Userpilot.shared.autoCaptureEngine.handleClickTracked(eventProperties)
    }

}
