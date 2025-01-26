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

internal extension UIImageView {
    // set image with fade in animation
    func setImageWithCrossfade(_ image: UIImage) {
        UIView.transition(with: self,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: { self.image = image },
                          completion: nil)
    }
}

internal extension UIImage {
    // Resize image to specific size
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// A convenience method to load an image from the Userpilot resource bundle.
    /// - Parameter imageName: The name of the image to be loaded.
    /// - Returns: The image from the Userpilot resource bundle, or `nil` if not found.
    static func userpilotImage(named imageName: String) -> UIImage? {
        return UIImage(named: imageName, in: Userpilot.resourceBundle, compatibleWith: nil)
    }

}
