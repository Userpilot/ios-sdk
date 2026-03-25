//
//  SwiftUIViewResolver.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  SwiftUIViewResolver provides utilities for resolving click properties and generating
//  unique identifiers for SwiftUI view elements in automatic analytics capture.
//

import UIKit

/// `SwiftUIViewResolver` provides utilities for SwiftUI view click tracking and identification.
internal enum SwiftUIViewResolver {
    // MARK: - Static Methods

    /// Resolves click properties from touch event on SwiftUI elements
    /// - Parameters:
    ///   - window: The window where the event occurred
    ///   - point: The touch point in window coordinates
    ///   - event: The UI event
    ///   - fallbackView: Fallback view if hit testing fails (also used for checking redaction flags)
    /// - Returns: Dictionary of click properties or nil
    static func resolveClickProperties(
        window: UIWindow,
        point: CGPoint,
        event: UIEvent,
        fallbackView: UIView
    ) -> [String: Any]? {
        if #available(iOS 18.0, *) {
            if let element = window.accessibilityHitTest(point, event: event) as? NSObject {
                return buildProperties(from: element, fallbackView: fallbackView)
            }
        }

        if let hitView = window.hitTest(point, with: event) {
            return buildProperties(from: hitView)
        }

        return buildProperties(from: fallbackView)
    }

    /// Generates a unique identifier for click events
    /// - Parameters:
    ///   - screenName: The current screen name
    ///   - properties: Event properties
    /// - Returns: Unique event identifier string
    static func generateEventUID(screenName: String, properties: [String: Any]) -> String {
        let elementType = properties["element_type"] as? String ?? "swiftui_view"
        let label = properties["element_label"] as? String ?? ""
        let identifier = properties["accessibility_id"] as? String ?? ""
        let components = [
            screenName,
            elementType,
            label,
            identifier
        ].joined(separator: "|")

        return String(components.hashValue)
    }

    /// Builds click properties from an NSObject element
    /// - Parameters:
    ///   - element: The NSObject to extract properties from
    ///   - fallbackView: The UIView to use for checking redaction flags (since NSObject doesn't have those)
    /// - Returns: Dictionary of element properties
    private static func buildProperties(from element: NSObject, fallbackView: UIView) -> [String: Any] {
        // If the element is a UIView, use the UIView-specific method with redaction support
        if let view = element as? UIView {
            return buildProperties(from: view)
        }

        // For non-UIView accessibility elements (like SwiftUI.AccessibilityNode on iOS 18+),
        // we extract data from the accessibility element but check redaction flags on the fallback UIView
        let rawLabel = element.accessibilityLabel
        let identifier = element.value(forKey: "accessibilityIdentifier") as? String
        let traits = element.accessibilityTraits
        let isButton = traits.contains(.button)
        let elementType = isButton ? "swiftui_button" : "swiftui_view"

        var properties: [String: Any] = [
            "element_type": elementType
        ]

        // Apply redaction using the fallback view's settings
        if let rawLabel, !rawLabel.isEmpty {
            let label = fallbackView.shouldRedactText() ? "****" : rawLabel
            properties["element_label"] = label
        }

        // Apply accessibility identifier redaction using the fallback view's settings
        if let identifier, !identifier.isEmpty {
            let redactedIdentifier = fallbackView.shouldRedactAccessibilityLabel() ? "****" : identifier
            properties["accessibility_id"] = redactedIdentifier
        }

        return properties
    }

    /// Builds click properties from a UIView element
    /// - Parameter view: The UIView to extract properties from
    /// - Returns: Dictionary of element properties
    private static func buildProperties(from view: UIView) -> [String: Any] {
        let rawLabel = view.accessibilityLabel ?? view.extractFallbackLabel()
        let identifier = view.accessibilityIdentifier
        let traits = view.accessibilityTraits
        let isButton = traits.contains(.button)
        let elementType = isButton ? "swiftui_button" : "swiftui_view"

        var properties: [String: Any] = [
            "element_type": elementType
        ]

        // Apply redaction if needed
        if let rawLabel, !rawLabel.isEmpty {
            let label = view.shouldRedactText() ? "****" : rawLabel
            properties["element_label"] = label
        }

        // Apply accessibility label redaction if needed
        if let identifier, !identifier.isEmpty {
            let redactedIdentifier = view.shouldRedactAccessibilityLabel() ? "****" : identifier
            properties["accessibility_id"] = redactedIdentifier
        }

        return properties
    }

}
