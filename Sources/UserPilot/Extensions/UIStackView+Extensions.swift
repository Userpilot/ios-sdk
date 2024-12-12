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

    func addView(_ view: UIView) {
        addArrangedSubview(view)
        view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            view.alpha = 1
        }
    }

    func clearViews() {
        self.arrangedSubviews.forEach { view in
            self.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}
