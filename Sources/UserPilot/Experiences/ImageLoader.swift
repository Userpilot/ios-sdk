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

internal protocol ImageLoading: AnyObject {
    /// Loads an image into the specified UIImageView from a given URL.
    /// - Parameters:
    ///   - target: The UIImageView where the image will be displayed.
    ///   - url: The URL of the image to load.
    ///   - placeholder: An optional UIColor used to create a placeholder image while loading.
    ///   - blurHash: An optional string representing a blur hash to generate an initial image.
    ///   - size: The target size for the image.
    func loadImage(target: UIImageView,
                   url: String,
                   placeholder: UIColor?,
                   blurHash: String?,
                   size: CGSize)
}

internal class ImageLoader: ImageLoading {

    // Shared image cache using NSCache, storing CachedImage instances
    private var imageCache = NSCache<NSString, CachedImage>()

    // Maintain a dictionary to track the last accessed date of each cached image
    private var imageAccessDates = [NSString: Date]()

    // Maximum allowed cache size in bytes (e.g., 10 MB)
    private let maxCacheSize: Int = 10 * 1024 * 1024

    private var storage: DataStoring

    // Private initializer to prevent instantiation from outside
    init(container: DIContainer) {
        self.storage = container.resolve(DataStoring.self)
        loadAccessDates()
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
            target.image = image
        }
    }

    /// Asynchronously loads an image from a URL and caches it.
    /// Supports both static images and GIFs.
    /// - Parameters:
    ///   - url: The URL of the image to load.
    ///   - completion: A completion handler with the loaded `UIImage` (optional).
    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: url.absoluteString)

        // Return the cached image if available
        if let cachedImageWrapper = imageCache.object(forKey: cacheKey) {
            cachedImageWrapper.lastAccessDate = Date() // Update access date
            imageAccessDates[cacheKey] = cachedImageWrapper.lastAccessDate
            saveAccessDates()
            completion(cachedImageWrapper.image) // Return cached image
            return
        }

        // Download the image asynchronously
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                completion(nil)
                return
            }

            let newImage = self.createImage(from: data)
            if let image = newImage {
                self.imageCache.setObject(CachedImage(image: image), forKey: cacheKey, cost: data.count)
                self.imageAccessDates[cacheKey] = Date()
                self.saveAccessDates()
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }

            // Check and manage cache size
            self.manageCacheSize()
        }.resume()
    }

    /// Clears all images stored in the cache.
    private func clearCache() {
        imageCache.removeAllObjects()
        imageAccessDates.removeAll()
        storage.imagesCache = [:]
    }

    /// Manage the cache size by removing the least recently used items if the cache size exceeds the maximum limit.
    private func manageCacheSize() {
        var currentCacheSize = imageCache.totalCostLimit

        // Remove least recently used items until cache size is below the limit
        while currentCacheSize > maxCacheSize, let leastRecentlyUsedKey = findLeastRecentlyUsedKey() {
            imageCache.removeObject(forKey: leastRecentlyUsedKey)
            imageAccessDates.removeValue(forKey: leastRecentlyUsedKey)

            // Recalculate the current cache size after removal
            currentCacheSize = imageCache.totalCostLimit
            saveAccessDates()
        }
    }

    /// Find the least recently used image key in the cache.
    /// - Returns: The key of the least recently used image.
    private func findLeastRecentlyUsedKey() -> NSString? {
        return imageAccessDates.min { $0.value < $1.value }?.key
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

    /// Loads access dates from UserDefaults.
    private func loadAccessDates() {
        for (key, date) in storage.imagesCache {
            imageAccessDates[NSString(string: key)] = date
        }
    }

    /// Saves access dates to UserDefaults.
    private func saveAccessDates() {
        storage.imagesCache = imageAccessDates
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
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Set the fill color
        context.setFillColor(color.cgColor)

        // Fill the rectangle with the color
        context.fill(rect)

        // Create a UIImage from the context
        let image = UIGraphicsGetImageFromCurrentImageContext()

        // End the image context
        UIGraphicsEndImageContext()

        return image
    }
}

//  This class represents a cached image along with its last access date.
//  The `CachedImage` class is used to store images in the image cache,
//  allowing the `ImageLoader` class to efficiently manage memory and access
//  recently used images. By tracking the last access date, the caching
//  mechanism can determine which images are least recently used, enabling
//  efficient cache management and size control. 
internal class CachedImage: NSObject {
    var image: UIImage
    var lastAccessDate: Date

    init(image: UIImage) {
        self.image = image
        self.lastAccessDate = Date()
    }
}
