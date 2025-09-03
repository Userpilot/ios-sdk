//
//  UIStackView+Extensions.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/09/2024.
//
//  - `addItemToStackView(_:withAnimationDuration:)` adds a view to the stack
//    view with a fade-in animation.
//  - `removeItemFromStackView(_:withAnimationDuration:)` removes a view from
//    the stack view with a fade-out animation.
//

import Foundation
import UIKit

extension UIStackView {

    func addItemToStackView(_ item: UIView, withAnimationDuration duration: TimeInterval = 0.3) {
        item.alpha = 0
        self.addArrangedSubview(item)
        self.layoutIfNeeded()
        UIView.animate(withDuration: duration) {
            item.alpha = 1
            self.layoutIfNeeded()
        }
    }

    func removeItemFromStackView(_ item: UIView, withAnimationDuration duration: TimeInterval = 0.3) {
        // Step 1: Animate the disappearance of the view
        UIView.animate(withDuration: duration, animations: {
            item.alpha = 0 // Animate to invisible
            self.layoutIfNeeded() // Animate the layout change
        }, completion: { _ in
            // Step 2: Remove the view from the stack view
            self.removeArrangedSubview(item)
            item.removeFromSuperview() // Remove from view hierarchy
        })
    }

}
