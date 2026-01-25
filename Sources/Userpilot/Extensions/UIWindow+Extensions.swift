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
    // MARK: - Private Types

    /// Settings for automatic click capture modes
    private struct AutoCaptureClickSettings {
        /// Whether UIKit click tracking is enabled
        var uiKitEnabled: Bool = false

        /// Whether SwiftUI click tracking is enabled
        var swiftUIEnabled: Bool = false
    }

    /// Shared settings for auto capture click tracking
    private static var userpilotClickSettings = AutoCaptureClickSettings()

    // MARK: - Static Methods

    /// Updates auto capture click settings
    /// - Parameters:
    ///   - uiKitEnabled: Whether UIKit click tracking is enabled
    ///   - swiftUIEnabled: Whether SwiftUI click tracking is enabled
    static func updateAutoCaptureClicks(
        uiKitEnabled: Bool? = nil,
        swiftUIEnabled: Bool? = nil
    ) {
        if let uiKitEnabled = uiKitEnabled {
            userpilotClickSettings.uiKitEnabled = uiKitEnabled
        }
        if let swiftUIEnabled = swiftUIEnabled {
            userpilotClickSettings.swiftUIEnabled = swiftUIEnabled
        }
    }

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

        guard let touches = event.allTouches else { return }
        for touch in touches {
            if UIWindow.userpilotClickSettings.swiftUIEnabled,
               touch.phase == .ended,
               let view = touch.view { // SwiftUIViewTextResolver.isSwiftUIView(view) {
                let point = touch.location(in: self)
                handleSwiftUIClick(at: point, event: event, view: view)
                continue
            }

            if UIWindow.userpilotClickSettings.uiKitEnabled,
               touch.phase == .began,
               let view = touch.view {
                handleUIKitClick(on: view)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles UIKit click tracking for the given view
    /// - Parameter view: The UIView that was clicked
    private func handleUIKitClick(on view: UIView) {
        // 🔍 FILTER: Only track clicks on interactive/trackable views
//        guard shouldTrackClick(on: view) else {
//            return
//        }

        let trackingData = UIKitViewResolver.resolveElementData(view: view)
        var eventProperties = trackingData.toDictionary()
        eventProperties["type"] = "click"
        eventProperties["element_tag"] = UIKitViewResolver.elementTag(view: view)
        eventProperties["path"] = UIKitViewResolver.resolvePath(view: view)
        eventProperties["text"] = UIKitViewResolver.resolve(view: view) as Any
        eventProperties["auto_capture_source"] = "uikit"
        eventProperties.removeValue(forKey: "screen_name")
        eventProperties.removeValue(forKey: "event_uid")

        NotificationCenter.userpilot.post(
            name: .userpilotTrackedClick,
            object: self,
            userInfo: eventProperties
        )
    }

    /// Handles SwiftUI click tracking at the given point
    /// - Parameters:
    ///   - point: The touch point in window coordinates
    ///   - event: The UI event
    ///   - view: The UIView that was touched
    private func handleSwiftUIClick(at point: CGPoint, event: UIEvent, view: UIView) {
        var eventProperties = SwiftUIViewResolver.resolveClickProperties(
            window: self,
            point: point,
            event: event,
            fallbackView: view
        ) ?? [:]

        eventProperties["type"] = "click"
        eventProperties["auto_capture_source"] = "swiftui"
        eventProperties.removeValue(forKey: "screen_name")
        eventProperties.removeValue(forKey: "event_uid")

        NotificationCenter.userpilot.post(
            name: .userpilotTrackedClick,
            object: self,
            userInfo: eventProperties
        )
    }
}
