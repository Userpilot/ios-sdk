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

internal extension UIImage {
    /// Tries animation decoding first, then decodes the static image to cover `size` at its own aspect ratio.
    /// Larger sources are downscaled by ImageIO without a full-size intermediate; nothing is ever stretched.
    static func decoded(from data: Data, size: CGSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let image = animatedImage(from: source, fitting: size) { return image }
        guard let image = UIImage(data: data) else { return nil }
        guard let target = image.size.covering(size) else { return image }
        let scale = UIGraphicsImageRendererFormat.default().scale
        if max(image.size.width, image.size.height) * image.scale > max(target.width, target.height) * scale,
           let thumbnail = source.thumbnail(at: 0, maxPixelSize: max(target.width, target.height) * scale) {
            return UIImage(cgImage: thumbnail, scale: scale, orientation: .up)
        }
        return image.resized(to: target) ?? image
    }

    // Resize image to specific size
    func resized(to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Keeps the existing ImageIO fallback on iOS 13, where UTType.gif is unavailable.
    /// A single frame is a still image and takes the static path. Frames are only ever downscaled,
    /// and their count, order and summed delay are unchanged.
    private static func animatedImage(from imageSource: CGImageSource, fitting size: CGSize) -> UIImage? {
        if #available(iOS 14.0, *) {
            guard let type = CGImageSourceGetType(imageSource), type == UTType.gif.identifier as CFString else {
                return nil
            }
        }
        let count = CGImageSourceGetCount(imageSource)
        guard count > 1 else { return nil }

        let scale = UIGraphicsImageRendererFormat.default().scale
        let maxPixelSize = imageSource.pixelSize(at: 0)
            .flatMap { $0.covering(size) }
            .map { max($0.width, $0.height) * scale }
        var frames: [UIImage] = []
        var totalDuration = 0.0
        for index in 0..<count {
            let frame = imageSource.pixelSize(at: index).flatMap { pixels -> CGImage? in
                guard let maxPixelSize, max(pixels.width, pixels.height) > maxPixelSize else { return nil }
                return imageSource.thumbnail(at: index, maxPixelSize: maxPixelSize)
            }
            if let frame {
                frames.append(UIImage(cgImage: frame, scale: scale, orientation: .up))
                totalDuration += imageSource.frameDelay(at: index)
            } else if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                frames.append(UIImage(cgImage: cgImage))
                totalDuration += imageSource.frameDelay(at: index)
            }
        }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }
}

private extension CGSize {
    /// The smallest size with this size's aspect ratio that covers `box`; nil for an empty size or box.
    func covering(_ box: CGSize) -> CGSize? {
        guard width > 0, height > 0, box.width > 0, box.height > 0 else { return nil }
        let scale = max(box.width / width, box.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

private extension CGImageSource {
    /// Pixel dimensions of one frame, before EXIF orientation.
    func pixelSize(at index: Int) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(self, index, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Decodes straight to the requested longest side, applying EXIF orientation like `UIImage(data:)`.
    func thumbnail(at index: Int, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(ceil(maxPixelSize))
        ]
        return CGImageSourceCreateThumbnailAtIndex(self, index, options as CFDictionary)
    }

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
