//
//  ImageLoader.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 03/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This module provides an interface and implementation for loading images from a URL
//  and caching them for efficient reuse. The `ImageLoading` protocol defines the
//  requirements for any image loading implementation, while the `ImageLoader` class
//  provides a concrete implementation that supports loading static images and GIFs.
//
//  The `ImageLoader` class utilizes an NSCache to store images, tracking their
//  access dates to manage cache size effectively. It supports loading images
//  asynchronously and provides placeholder images while the loading process is
//  ongoing. The cache is automatically managed, ensuring that it does not exceed
//  a specified maximum size, and allows for clearing the cache if needed.
//
//  Usage:
//  - To load an image, create an instance of `ImageLoader` and call
//    `loadImage(target:url:placeholder:blurHash:size:)` method, providing
//    the necessary parameters for the image to be loaded and displayed.
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/**
 ImageLoading Loads an image into the specified UIImageView from a given URL.
 */
internal protocol ImageLoading: AnyObject {
    /// Loading image to image view with blur effect
    func loadImage(target: UIImageView,
                   url: String,
                   placeholder: UIColor?,
                   blurHash: String?,
                   size: CGSize)
}

internal class ImageLoader: ImageLoading {

    private var fileStorageManager: FileStoring

    // Private initializer to prevent instantiation from outside
    init(container: DIContainer) {
        self.fileStorageManager = container.resolve(FileStoring.self)
    }

    func loadImage(target: UIImageView, url: String, placeholder: UIColor?, blurHash: String?, size: CGSize) {
        guard let url = URL(string: url) else { return }
        if let blurHash = blurHash, let image = UIImage(blurHash: blurHash, size: size) {
            target.image = image
        } else {
            target.image = imageFromColor(color: placeholder ?? UIColor.clear, size: size)
        }

        loadImage(from: url) { [weak self] image in
            guard self != nil, let image = image else { return }
            target.setImageWithCrossfade(image)
        }
    }

    /// Asynchronously loads an image from a URL and caches it.
    /// Supports both static images and GIFs.
    /// - Parameters:
    ///   - url: The URL of the image to load.
    ///   - completion: A completion handler with the loaded `UIImage` (optional).
    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check if the image is stored on disk (file system)
//        if let cachedImage = loadImageFromDisk(url: url) {
//            completion(cachedImage)
//            return
//        }

        // Download the image asynchronously
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil)
                return
            }

            let newImage = self.createImage(from: data)
            if let image = newImage {
                self.saveImageToDisk(image: data, url: url)

                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }

    /// Creates an image from the data, supporting static images and GIFs.
    /// - Parameter data: The data of the image.
    /// - Returns: A `UIImage` if the data represents an image, otherwise `nil`.
    private func createImage(from data: Data) -> UIImage? {
        if let gifImage = createAnimatedImage(from: data) {
            return gifImage
        } else if let staticImage = UIImage(data: data) {
            return staticImage
        }
        return nil
    }

    /// Creates an animated UIImage from GIF data.
    /// - Parameter data: The data of the GIF.
    /// - Returns: An animated `UIImage` if the data represents a GIF, otherwise `nil`.
    private func createAnimatedImage(from data: Data) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        // Check if the data is of type GIF using UTType for iOS 14+
        if #available(iOS 14.0, *) {
            guard let type = CGImageSourceGetType(imageSource), type == UTType.gif.identifier as CFString else {
                return nil
            }
        }

        var frames: [UIImage] = []
        var totalDuration: Double = 0.0
        let frameCount = CGImageSourceGetCount(imageSource)

        for index in 0..<frameCount {
            // Get the image for each frame
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                let frame = UIImage(cgImage: cgImage)
                frames.append(frame)

                // Get the frame duration (delay time)
                let frameDuration = getFrameDelay(for: imageSource, at: index)
                totalDuration += frameDuration
            }
        }

        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    /// Gets the delay time for each frame in the GIF animation.
    /// - Parameters:
    ///   - imageSource: The `CGImageSource` object.
    ///   - index: The index of the frame.
    /// - Returns: The delay time (in seconds) for the frame.
    private func getFrameDelay(for imageSource: CGImageSource, at index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1 // Default to 0.1 seconds if no delay is found
        }

        // Get the unclamped delay time (if available), otherwise fallback to the normal delay time
        let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double ??
                        gifProperties[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1

        // Ensure the delay is non-zero (default to 0.1 seconds if the value is 0)
        return delayTime > 0 ? delayTime : 0.1
    }

    /// Creates a UIImage from a specified color.
    /// - Parameters:
    ///   - color: The color to fill the image.
    ///   - size: The size of the image (default is 1x1 pixel).
    /// - Returns: A UIImage filled with the specified color.
    func imageFromColor(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage? {
        // Create a rectangle with the specified size
        let rect = CGRect(origin: .zero, size: size)

        // Begin a new image context
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)

        // Get the current context
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Fill the context with the specified color
        context.setFillColor(color.cgColor)
        context.fill(rect)

        // Create an image from the context
        let image = UIGraphicsGetImageFromCurrentImageContext()

        // End the image context
        UIGraphicsEndImageContext()

        return image
    }

    /// Saves an image to the file system for future use.
    /// - Parameters:
    ///   - image: The image to save.
    ///   - url: The URL used for the image.
    private func saveImageToDisk(image: Data, url: URL) {
        fileStorageManager.saveImage(image, withURL: url.absoluteString)
    }

    /// Loads an image from the file system.
    /// - Parameter url: The URL used for the image.
    /// - Returns: The image if it exists on disk, otherwise `nil`.
    private func loadImageFromDisk(url: URL) -> UIImage? {
        return fileStorageManager.loadImage(url.absoluteString)
    }
}
