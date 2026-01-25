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
    ///   - fallbackView: Fallback view if hit testing fails
    /// - Returns: Dictionary of click properties or nil
    static func resolveClickProperties(
        window: UIWindow,
        point: CGPoint,
        event: UIEvent,
        fallbackView: UIView
    ) -> [String: Any]? {
        if #available(iOS 18.0, *) {
            if let element = window.accessibilityHitTest(point, event: event) as? NSObject {
                return buildProperties(from: element)
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
    /// - Parameter element: The NSObject to extract properties from
    /// - Returns: Dictionary of element properties
    private static func buildProperties(from element: NSObject) -> [String: Any] {
        let label = element.accessibilityLabel
        let identifier = element.value(forKey: "accessibilityIdentifier") as? String
        let traits = element.accessibilityTraits
        let isButton = traits.contains(.button)
        let elementType = isButton ? "swiftui_button" : "swiftui_view"

        var properties: [String: Any] = [
            "element_type": elementType
        ]

        if let label, !label.isEmpty {
            properties["element_label"] = label
        }
        if let identifier, !identifier.isEmpty {
            properties["accessibility_id"] = identifier
        }

        return properties
    }

    /// Builds click properties from a UIView element
    /// - Parameter view: The UIView to extract properties from
    /// - Returns: Dictionary of element properties
    private static func buildProperties(from view: UIView) -> [String: Any] {
        let label = view.accessibilityLabel ?? view.extractFallbackLabel()
        let identifier = view.accessibilityIdentifier
        let traits = view.accessibilityTraits
        let isButton = traits.contains(.button)
        let elementType = isButton ? "swiftui_button" : "swiftui_view"

        var properties: [String: Any] = [
            "element_type": elementType
        ]

        if let label, !label.isEmpty {
            properties["element_label"] = label
        }
        if let identifier, !identifier.isEmpty {
            properties["accessibility_id"] = identifier
        }

        return properties
    }

}
