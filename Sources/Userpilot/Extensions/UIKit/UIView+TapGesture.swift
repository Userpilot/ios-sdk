//
//  UIView+TapGesture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Adds a closure-backed tap recognizer without changing control or input touch handling.
//

import UIKit

internal extension UIView {
    /// Adds a tap gesture recognizer to the `UIView`, allowing you to execute a closure when tapped.
    /// - Parameters:
    ///   - tapNumber: The number of taps required to recognize the gesture. Defaults to 1.
    ///   - closure: A closure to be executed when the gesture is recognized.
    func addTapGesture(
        tapNumber: Int = 1,
        _ closure: (() -> Void)?
    ) {
        guard let closure = closure else { return }

        // Create a bindable tap gesture recognizer with the provided closure
        let tap = BindableGestureRecognizer(action: closure)
        tap.numberOfTapsRequired = tapNumber
        tap.cancelsTouchesInView = false
        isUserInteractionEnabled = true

        // Add the gesture recognizer to the view
        addGestureRecognizer(tap)
    }
}
