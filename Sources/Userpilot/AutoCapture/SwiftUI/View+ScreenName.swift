//
//  View+ScreenName.swift
//  Userpilot
//
//  Created by Motasem Hamed on 11/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+ScreenName provides SwiftUI view modifiers for setting custom screen names
//  for automatic screen tracking using PreferenceKey and UIKit bridging.
//

import SwiftUI
import UIKit

/// PreferenceKey for passing screen names up the SwiftUI view hierarchy
private struct ScreenNamePreferenceKey: PreferenceKey {
    // MARK: - PreferenceKey Protocol

    /// Default value for the preference key
    static var defaultValue: String?

    /// Reduces multiple values by taking the first non-nil value
    static func reduce(value: inout String?, nextValue: () -> String?) {
        // Take the first non-nil value (closest to root)
        value = value ?? nextValue()
    }
}

/// Bridge view that reads PreferenceKey and sets it on UIView for UIKit access
private struct ScreenNameBridge: UIViewRepresentable {
    // MARK: - Properties

    /// The screen name to set on the UIView
    let screenName: String?

    // MARK: - UIViewRepresentable Protocol

    /// Creates a UIView to bridge screen name to UIKit
    /// - Parameter context: The context for the view
    /// - Returns: A configured UIView
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.frame = .zero
        if let screenName = screenName {
            view.up_screenName = screenName
        }
        return view
    }

    /// Updates the UIView with the screen name
    /// - Parameters:
    ///   - uiView: The UIView to update
    ///   - context: The context for the view
    func updateUIView(_ uiView: UIView, context: Context) {
        if let screenName = screenName {
            uiView.up_screenName = screenName
        }
    }
}

/// View modifier that uses PreferenceKey (SwiftUI-native) and bridges to UIKit
private struct ScreenNameModifier: ViewModifier {
    // MARK: - Properties

    /// The screen name to set
    let name: String

    // MARK: - ViewModifier Protocol

    /// Applies the screen name modifier to the content
    /// - Parameter content: The content to modify
    /// - Returns: Modified view with screen name set
    func body(content: Self.Content) -> some View {
        content
            .preference(key: ScreenNamePreferenceKey.self, value: name)
            .background(
                GeometryReader { _ in
                    ScreenNameBridge(screenName: name)
                        .frame(width: 0, height: 0)
                }
            )
    }
}

/// Extension providing screen name functionality for SwiftUI views
extension View {
    /// Sets a custom screen name for automatic screen tracking
    /// - Parameter name: The screen name to use for tracking
    /// - Returns: A view with the screen name set
    public func userpilotScreenName(_ name: String) -> some View {
        modifier(ScreenNameModifier(name: name))
    }
}
