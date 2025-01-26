//
//  UIButton+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 23/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `UIButton+Extension` contains extensions with helper methods for the `UIButton` class.
//

import UIKit

extension UIButton {

    /// Configures the button with a title and a color.
    /// - Parameters:
    ///   - title: The title text to set for the button.
    ///   - color: The color to apply to the title text.
    func config(with title: String, and color: UIColor) {
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color
            ]
        )

        self.setAttributedTitle(attributedTitle, for: .normal)
        self.setTitle(title, for: .normal)
        self.setTitleColor(color, for: .normal)
    }
}
