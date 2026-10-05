//
//  WindowTouchFilter.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Filters window-level touches before payload conversion, preserving keyboard,
//  structural-container and metadata checks for the owning SDK instance.
//

import UIKit

/// Stateless window-touch filtering. The framework flag is read only at its existing SwiftUI check.
internal enum WindowTouchFilter {
    /// `UIScrollView` / `UITableView` / `UICollectionView` / `UIStackView`, bare `UIView`, and generic SwiftUI host.
    private static let structuralWindowTouchElementTypes: Set<String> = [
        String(describing: UIScrollView.self),
        String(describing: UITableView.self),
        String(describing: UICollectionView.self),
        String(describing: UIStackView.self),
        String(describing: UIView.self),
        Constants.AutoCapture.swiftUIView
    ]

    /// SwiftUI framework-internal layout / hosting scaffolding classes that surface as the resolved
    /// leaf when a tap lands on container background rather than an interactive element. These never
    /// carry developer-meaningful text/label/id, so a tap resolving to one of them with no metadata is
    /// a dead click. The non-underscore names below are not caught by `windowTouchIsPrivateUIKitElementType`
    /// (which only handles `_UI…` / `_NS…`). They are matched only after the metadata check, so taps on
    /// these classes that *do* carry text/accessibility info are still published unchanged.
    private static let swiftUIStructuralContainerTypes: Set<String> = [
        "PlatformGroupContainer",
        "PlatformContainer",
        "PlatformViewHost",
        "HostingView",
        "HostingScrollView"
    ]

    /// Private / internal UIKit view class names (e.g. `_UITextLayoutCanvasView`) — never publish as window taps.
    private static func windowTouchIsPrivateUIKitElementType(_ elementType: String) -> Bool {
        if elementType.hasPrefix("_UI") { return true }
        if elementType.hasPrefix("_NS") { return true }
        return false
    }

    /// System keyboard chrome (`UIKBKeyView`, `TUIKBKeyView`, `UIKeyboardImpl`, …).
    private static func windowTouchIsSystemKeyboardChrome(
        elementType: String,
        hierarchy: String?
    ) -> Bool {
        if elementType.hasPrefix("UIKB") { return true }
        if elementType.hasPrefix("TUIKB") { return true }
        if elementType.contains("TUIKeyplane") || elementType.contains("TUIKeyboard") { return true }
        if elementType.contains("UIKeyboardImpl") || elementType.contains("UIKeyboardLayout") {
            return true
        }
        if elementType.contains("UIKeyboardAutomatic") { return true }
        if elementType.contains("UIInputSet") || elementType.contains("_UIKB") { return true }
        if elementType.contains("UICompatibilityInputView") { return true }
        guard let hierarchy else { return false }
        if hierarchy.contains("UIKeyboardImpl") || hierarchy.contains("UIKBKeyView") { return true }
        if hierarchy.contains("TUIKB") || hierarchy.contains("UIInputSet") { return true }
        return false
    }

    /// SwiftUI scaffolding leaf (hosting / platform container) with no metadata — a dead click.
    ///
    /// Only consulted for SwiftUI-configured apps and only after `windowTouchHasMetadata` has already
    /// returned `false`, so this can never suppress a tap that resolved any text / accessibility signal.
    /// These class names are SwiftUI-exclusive, so UIKit capture is unaffected.
    private static func windowTouchIsSwiftUIStructuralContainer(
        _ elementType: String, config: Userpilot.Config
    ) -> Bool {
        guard config.appFramework == .SwiftUI else { return false }
        if Self.swiftUIStructuralContainerTypes.contains(elementType) { return true }
        // SwiftUI's private hosting wrappers embed these stable, framework-internal substrings.
        if elementType.contains("HostingView") || elementType.contains("HostingScrollView") {
            return true
        }
        return false
    }

    /// True when any identifying string is present (including redacted placeholder).
    private static func windowTouchHasMetadata(_ properties: [String: Any]) -> Bool {
        let keys: [String] = [
            Constants.AutoCapture.targetText,
            Constants.AutoCapture.accessibilityLabel,
            Constants.AutoCapture.accessibilityIdentifier
        ]
        for key in keys {
            guard let string = properties[key] as? String else { continue }
            if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    /// Drops taps on structural containers, private `_UI…` internals, and bare SwiftUI views when there is no signal.
    static func shouldPublishWindowLevelTouch(
        _ properties: [String: Any], config: Userpilot.Config
    ) -> Bool {
        guard let elementType = properties[Constants.AutoCapture.targetClass] as? String else {
            return false
        }
        if windowTouchIsPrivateUIKitElementType(elementType) {
            return false
        }
        let hierarchy = properties[Constants.AutoCapture.hierarchy] as? String
        if windowTouchIsSystemKeyboardChrome(elementType: elementType, hierarchy: hierarchy) {
            return false
        }
        if windowTouchHasMetadata(properties) {
            return true
        }
        if windowTouchIsSwiftUIStructuralContainer(elementType, config: config) {
            return false
        }
        if Self.structuralWindowTouchElementTypes.contains(elementType) {
            return false
        }
        return true
    }
}
