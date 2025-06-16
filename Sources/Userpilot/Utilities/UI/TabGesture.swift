//
//  TabGesture.kt
//  Userpilot SDK
//
//  Created by Motasem Hamed on 26/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A class to add tab gesture to any view.
//
// swiftlint:disable all
import UIKit

internal final class BindableGestureRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private var action: () -> Void

    /// Initializes the gesture recognizer with a closure to be executed on tap.
    /// - Parameter action: A closure to execute when the gesture is recognized.
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        self.addTarget(self, action: #selector(execute))
    }

    /// Overrides the touch handling to ensure gesture works with keyboard
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        // Attempt to end editing (dismiss keyboard) if needed
        if let view = self.view {
            view.endEditing(true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    /// Executes the stored action when the gesture is recognized.
    @objc private func execute() {
        action()
    }
}

internal extension UIView {
    /// Adds a tap gesture recognizer to the `UIView`, allowing you to execute a closure when tapped.
    /// - Parameters:
    ///   - tapNumber: The number of taps required to recognize the gesture. Defaults to 1.
    ///   - closure: A closure to be executed when the gesture is recognized.
    func addTapGesture(tapNumber: Int = 1, _ closure: (() -> Void)?) {
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
// swiftlint:enable all
