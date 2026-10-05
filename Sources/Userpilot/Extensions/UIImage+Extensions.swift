//
//  UIImage+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 07/11/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  UIImage helpers decode experience images, resize static images, and load bundled
//  resources. UIImageView applies the shared crossfade when an image is displayed.
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

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
    /// Tries animation decoding first, then resizes the static-image fallback when possible.
    static func decoded(from data: Data, size: CGSize) -> UIImage? {
        if let image = animatedImage(from: data) { return image }
        guard let image = UIImage(data: data) else { return nil }
        return image.resized(to: size) ?? image
    }

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

    /// Keeps the existing ImageIO fallback on iOS 13, where UTType.gif is unavailable.
    private static func animatedImage(from data: Data) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if #available(iOS 14.0, *) {
            guard let type = CGImageSourceGetType(imageSource), type == UTType.gif.identifier as CFString else {
                return nil
            }
        }

        var frames: [UIImage] = []
        var totalDuration = 0.0
        for index in 0..<CGImageSourceGetCount(imageSource) {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                frames.append(UIImage(cgImage: cgImage))
                totalDuration += imageSource.frameDelay(at: index)
            }
        }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }
}

private extension CGImageSource {
    /// Prefers the unclamped GIF delay and retains the 0.1-second fallback for missing or invalid values.
    func frameDelay(at index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(self, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double ??
            gifProperties[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
        return delayTime > 0 ? delayTime : 0.1
    }
}
