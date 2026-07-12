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
        self.delegate = self
    }

    /// Ignore touches that land on a text input, control, or table-view cell.
    /// Text inputs/controls: otherwise tapping a focused text field would dismiss
    /// the keyboard and immediately re-focus it, producing a visible show/hide
    /// toggle. Table cells: those taps belong to the table's selection handling
    /// (which manages the keyboard itself); letting this recognizer also fire
    /// `endEditing` fights that handling and toggles the keyboard.
    /// Genuine background taps still fire the action (which calls `endEditing`).
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var candidate = touch.view
        while let view = candidate {
            if view is UITextField || view is UITextView || view is UIControl || view is UITableViewCell {
                return false
            }
            candidate = view.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
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
// swiftlint:enable all
