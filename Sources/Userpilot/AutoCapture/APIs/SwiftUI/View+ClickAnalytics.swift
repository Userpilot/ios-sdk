//
//  View+ClickAnalytics.swift
//  Userpilot
//
//  Created by Motasem Hamed on 13/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+ClickAnalytics provides SwiftUI view modifiers for enabling click analytics
//  recognition on views that may not be automatically detected as clickable.
//

import SwiftUI

// MARK: - Public API

/// Extension providing click analytics recognition functionality for SwiftUI views.
/// SwiftUI uses protocol extensions; API is `public` (not `open`—only classes support `open`).
public extension View {

    /// Manually enables analytics collection and tooltip guides display on this view.
    ///
    /// Use this API when the Userpilot SDK does not automatically recognize a clickable feature.
    /// This is particularly useful in the following scenarios:
    ///
    /// 1. **Views with `.onTapGesture` modifiers**:
    ///    SwiftUI views using gestures like `.onTapGesture` don't always generate underlying
    ///    accessibility elements, which prevents the SDK from detecting them as clickable.
    ///
    /// 2. **Container views with TapGestures**:
    ///    Container views (VStack, HStack, ZStack, LazyHStack, LazyVStack, LazyVGrid,
    ///    GeometryReader, LazyHGrid) with tap gestures are purely declarative and may not
    ///    be recognized as interactive elements.
    ///
    /// ## How it works
    ///
    /// This modifier applies Apple's native accessibility APIs to:
    /// - Combine child accessibility elements into a single element
    /// - Mark the view as a button, making it recognizable as a clickable element
    ///
    /// This enables the Userpilot SDK's UIKit-based scanner to properly identify and
    /// track interactions with these SwiftUI components.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // Example 1: VStack with onTapGesture
    /// VStack {
    ///     Text("Tap me")
    ///     Image(systemName: "hand.tap")
    /// }
    /// .onTapGesture {
    ///     print("Tapped!")
    /// }
    /// .userpilotRecognizeClickAnalytics()
    ///
    /// // Example 2: Custom button-like component
    /// HStack {
    ///     Image(systemName: "star.fill")
    ///     Text("Favorite")
    /// }
    /// .padding()
    /// .background(Color.blue)
    /// .cornerRadius(8)
    /// .onTapGesture {
    ///     toggleFavorite()
    /// }
    /// .userpilotRecognizeClickAnalytics()
    ///
    /// // Example 3: ZStack with tap gesture
    /// ZStack {
    ///     RoundedRectangle(cornerRadius: 10)
    ///         .fill(Color.green)
    ///     Text("Custom Button")
    /// }
    /// .frame(width: 200, height: 50)
    /// .onTapGesture {
    ///     performAction()
    /// }
    /// .userpilotRecognizeClickAnalytics()
    /// ```
    ///
    /// ## When NOT to use this API
    ///
    /// You do NOT need to use this API for:
    /// - Standard SwiftUI `Button` views (automatically recognized)
    /// - `NavigationLink` views (automatically recognized)
    /// - Views that already have proper accessibility traits
    ///
    /// ## Alternative approach
    ///
    /// If you prefer not to use a Userpilot-specific API, you can achieve the same result
    /// by applying Apple's native accessibility modifiers directly:
    ///
    /// ```swift
    /// .accessibilityElement(children: .combine)
    /// .accessibilityAddTraits([.isButton])
    /// ```
    ///
    /// Enables click analytics recognition for SwiftUI views
    /// - Parameter label: Optional accessibility label for the view
    /// - Returns: A view with enhanced accessibility traits for click analytics recognition
    public func userpilotRecognizeClickAnalytics(_ label: String? = nil) -> some View {
        self.modifier(UserpilotClickRecognitionModifier(label: label))
    }
}

// MARK: - Private

/// Modifier that applies accessibility traits to make views recognizable as clickable elements
private struct UserpilotClickRecognitionModifier: ViewModifier {
    // MARK: - Properties

    /// Optional accessibility label for the view
    let label: String?

    private var stableIdentifierSeed: String {
        let typeName = String(reflecting: Content.self)
        if let label, !label.isEmpty {
            return "\(typeName)|\(label)"
        }
        return typeName
    }

    private var stableAccessibilityIdentifier: String {
        return "up_swiftui_\(stableIdentifierSeed.stableHash())"
    }

    func body(content: Self.Content) -> some View {
        if #available(iOS 14.0, *) {
            content
            // Combine all child accessibility elements into a single element
            // This is crucial for container views (VStack, HStack, etc.) to be
            // treated as a single interactive unit rather than separate elements
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(stableAccessibilityIdentifier)
                .applyIf(label != nil) { view in
                    view.accessibilityLabel(label!)
                }
            // Add button trait to signal this is an interactive/clickable element
            // This helps UIKit-based accessibility scanners (like Userpilot's)
            // identify the view as a button/clickable element
                .accessibilityAddTraits([.isButton])
        } else {
            // Fallback on earlier versions
        }

        // Note: We could also add .isSelected or .isLink traits if needed
        // but .isButton is the most universal for click tracking purposes
    }
}

private extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private extension String {
    func stableHash() -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return String(format: "%016llx", hash)
    }
}
