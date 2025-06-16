//
//  UIStackView+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 11/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `UIStackView+Extension` contains extensions with helper methods for the `UIStackView` class.
//

import Foundation
import UIKit

internal extension UIStackView {

    /// Adds a view to the stack view with a fade-in animation.
    /// - Parameter view: The view to add as an arranged subview.
    func addView(_ view: UIView) {
        addArrangedSubview(view)
        view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            view.alpha = 1
        }
    }

    /// Removes all arranged subviews from the stack view.
    func clearViews() {
        self.arrangedSubviews.forEach { view in
            self.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    /// Adds multiple views to the stack view without animation.
    /// - Parameter views: An array of views to add as arranged subviews.
    func addArrangedSubviews(_ views: [UIView]) {
        for view in views {
            addArrangedSubview(view)
        }
    }
}
