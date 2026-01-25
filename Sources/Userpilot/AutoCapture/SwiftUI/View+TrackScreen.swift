//
//  View+TrackScreen.swift
//  Userpilot
//
//  Created by Motasem Hamed on 22/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+TrackScreen provides SwiftUI view modifiers for manual screen tracking
//  by posting screen events when views appear.
//

import Foundation
import SwiftUI

/// Extension providing screen tracking functionality for SwiftUI views
public extension View {
    /// Marks a SwiftUI View to be tracked as a screen event when it appears
    /// - Parameter screenName: The name of the screen (defaults to view type)
    /// - Returns: A modified view that will be tracked as a screen
    func trackScreen(_ screenName: String? = nil) -> some View {
        let screenEventName = screenName ?? "\(type(of: self))"
        return modifier(UserpilotSwiftUIViewModifier(screenEventName: screenEventName))
    }
}

/// Internal modifier that tracks screen events when views appear
private struct UserpilotSwiftUIViewModifier: ViewModifier {
    // MARK: - Properties

    /// The screen event name to track
    let screenEventName: String

    // MARK: - ViewModifier Protocol

    /// Applies the screen tracking modifier to the content
    /// - Parameter content: The content to modify
    /// - Returns: Modified view with screen tracking
    func body(content: Self.Content) -> some View {
        content.onAppear {
            NotificationCenter.userpilot.post(
                name: .userpilotTrackedScreenEvent,
                object: self,
                userInfo: Notification.toInfo(screenEventName)
            )
        }
    }
}
