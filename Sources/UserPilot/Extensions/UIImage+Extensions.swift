//  UIImageView+Extension.swift
//
//
//  Created by Motasem Hamed on 07/11/2024.
//
//  [Brief Description]
//  UIImageView+Extension file provides an extension for the `UIImageView` class,
// offering a helper method `setImageWithCrossfade` to apply a smooth crossfade animation
// when updating the image displayed in the image view.
//

import Foundation
import UIKit

extension UIImageView {

    func setImageWithCrossfade(_ image: UIImage) {
        UIView.transition(with: self,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: { self.image = image },
                          completion: nil)
    }
}
