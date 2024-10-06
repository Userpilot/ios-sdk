//
//  File.swift
//  
//
//  Created by Motasem Hamed on 03/10/2024.
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

internal class CachedImage: NSObject {
    var image: UIImage
    var lastAccessDate: Date

    init(image: UIImage) {
        self.image = image
        self.lastAccessDate = Date()
    }
}

internal class ImageLoader {
    // Shared instance for ImageLoader
    static let shared = ImageLoader()

    // Shared image cache using NSCache, storing CachedImage instances
    private var imageCache = NSCache<NSString, CachedImage>()

    // Maintain a dictionary to track the last accessed date of each cached image
    private var imageAccessDates = [NSString: Date]()

    // Maximum allowed cache size in bytes (e.g., 10 MB)
    private let maxCacheSize: Int = 10 * 1024 * 1024

    // UserDefaults key for storing access dates
    private let accessDatesKey = "imageAccessDates"

    // Private initializer to prevent instantiation from outside
    private init() {
        loadAccessDates()
    }

    /// Asynchronously loads an image from a URL and caches it.
    /// Supports both static images and GIFs.
    /// - Parameters:
    ///   - url: The URL of the image to load.
    ///   - completion: A completion handler with the loaded `UIImage` (optional).
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
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

    /// Clears all images stored in the cache
    func clearCache() {
        imageCache.removeAllObjects()
        imageAccessDates.removeAll()
        UserDefaults.standard.removeObject(forKey: accessDatesKey)
    }

    /// Handle memory warnings by clearing the cache
    @objc func handleMemoryWarning() {
        clearCache()
    }

    /// Manage the cache size by removing the least recently used items if the cache size exceeds the maximum limit
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

    /// Find the least recently used image key in the cache
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

    /// Loads access dates from UserDefaults
    private func loadAccessDates() {
        if let savedDates = UserDefaults.standard.dictionary(forKey: accessDatesKey) as? [String: Date] {
            for (key, date) in savedDates {
                imageAccessDates[NSString(string: key)] = date
            }
        }
    }

    /// Saves access dates to UserDefaults
    private func saveAccessDates() {
        UserDefaults.standard.set(imageAccessDates, forKey: accessDatesKey)
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
}

//// MARK: - ImageLoader Manager
//
///// A singleton class to handle asynchronous image loading with caching support.
//internal class ImageLoader {
//    // Shared instance for ImageLoader
//    static let shared = ImageLoader()
//
//    // Shared image cache using NSCache, storing CachedImage instances
//    private var imageCache = NSCache<NSString, CachedImage>()
//
//    // Maintain a dictionary to track the last accessed date of each cached image
//     private var imageAccessDates = [NSString: Date]()
//     
//     // Maximum allowed cache size in bytes (e.g., 10 MB)
//     private let maxCacheSize: Int = 10 * 1024 * 1024
//    
//    // Private initializer to prevent instantiation from outside
//    private init() {}
//
//    /// Asynchronously loads an image from a URL and caches it.
//    /// Supports both static images and GIFs.
//    /// - Parameters:
//    ///   - url: The URL of the image to load.
//    ///   - completion: A completion handler with the loaded `UIImage` (optional).
//    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
//        let cacheKey = NSString(string: url.absoluteString)
//
//        // Return the cached image if available
//        if let cachedImageWrapper = imageCache.object(forKey: cacheKey) {
//            cachedImageWrapper.lastAccessDate = Date() // Update access date
//            completion(cachedImageWrapper.image) // Return cached image
//            return
//        }
//
//        // Download the image asynchronously
//        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
//            guard let self = self, let data = data, error == nil else {
//                completion(nil)
//                return
//            }
//
//            // Determine if the data represents a GIF
//            if let image = self.createAnimatedImage(from: data) {
//                self.imageCache.setObject(CachedImage(image: image), forKey: cacheKey, cost: data.count)
//                self.imageAccessDates[cacheKey] = Date()
//                DispatchQueue.main.async {
//                    completion(image)
//                }
//            } else if let image = UIImage(data: data) { // Static image case
//                self.imageCache.setObject(CachedImage(image: image), forKey: cacheKey, cost: data.count)
//                self.imageAccessDates[cacheKey] = Date()
//                DispatchQueue.main.async {
//                    completion(image)
//                }
//            } else {
//                DispatchQueue.main.async {
//                    completion(nil)
//                }
//            }
//            // Check and manage cache size
//            self.manageCacheSize()
//        }.resume()
//    }
//    
//    /// Clears all images stored in the cache
//    func clearCache() {
//        imageCache.removeAllObjects()
//        imageAccessDates.removeAll()
//    }
//
//    /// Handle memory warnings by clearing the cache
//    @objc func handleMemoryWarning() {
//        clearCache()
//    }
//
//    /// Manage the cache size by removing the least recently used items if the cache size exceeds the maximum limit
//    private func manageCacheSize() {
//        var currentCacheSize = imageCache.totalCostLimit
//
//        // Remove least recently used items until cache size is below the limit
//        while currentCacheSize > maxCacheSize, let leastRecentlyUsedKey = findLeastRecentlyUsedKey() {
//            imageCache.removeObject(forKey: leastRecentlyUsedKey)
//            imageAccessDates.removeValue(forKey: leastRecentlyUsedKey)
//
//            // Recalculate the current cache size after removal
//            currentCacheSize = imageCache.totalCostLimit
//        }
//    }
//
//    /// Find the least recently used image key in the cache
//    private func findLeastRecentlyUsedKey() -> NSString? {
//        return imageAccessDates.min { $0.value < $1.value }?.key
//    }
//
//    /// Creates an animated UIImage from GIF data.
//    /// - Parameter data: The data of the GIF.
//    /// - Returns: An animated `UIImage` if the data represents a GIF, otherwise `nil`.
//    private func createAnimatedImage(from data: Data) -> UIImage? {
//        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
//            return nil
//        }
//
//        // Check if the data is of type GIF using UTType for iOS 14+
//        if #available(iOS 14.0, *) {
//            guard let type = CGImageSourceGetType(imageSource), type == UTType.gif.identifier as CFString else {
//                return nil
//            }
//        }
//
//        var frames: [UIImage] = []
//        var totalDuration: Double = 0.0
//        let frameCount = CGImageSourceGetCount(imageSource)
//
//        for index in 0..<frameCount {
//            // Get the image for each frame
//            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
//                let frame = UIImage(cgImage: cgImage)
//                frames.append(frame)
//
//                // Get the frame duration (delay time)
//                let frameDuration = getFrameDelay(for: imageSource, at: index)
//                totalDuration += frameDuration
//            }
//        }
//
//        return UIImage.animatedImage(with: frames, duration: totalDuration)
//    }
//
//    /// Gets the delay time for each frame in the GIF animation.
//    /// - Parameters:
//    ///   - imageSource: The `CGImageSource` object.
//    ///   - index: The index of the frame.
//    /// - Returns: The delay time (in seconds) for the frame.
//    private func getFrameDelay(for imageSource: CGImageSource, at index: Int) -> Double {
//        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any],
//              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
//            return 0.1 // Default to 0.1 seconds if no delay is found
//        }
//
//        // Get the unclamped delay time (if available), otherwise fallback to the normal delay time
//        let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double ??
//                        gifProperties[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
//
//        // Ensure the delay is non-zero (default to 0.1 seconds if the value is 0)
//        return delayTime > 0 ? delayTime : 0.1
//    }
//}

// MARK: - UIImageView Extension

internal extension UIImageView {

    /// Sets the image from a URL with optional caching and GIF support.
    /// - Parameters:
    ///   - url: The URL of the image to load.
    ///   - placeholder: An optional placeholder image to show while loading.
    func setImage(from url: String,
                  placeholder: UIColor? = nil,
                  blurHash: String? = nil,
                  size: CGSize = CGSize(width: 16, height: 16)) {
        guard let url = URL(string: url) else { return }
        if let blurHash = blurHash, let image = UIImage(blurHash: blurHash, size: size) {
            self.image = image
        } else {
            self.backgroundColor = placeholder ?? UIColor.clear
        }

        // Use the ImageLoader to download and cache the image
        ImageLoader.shared.loadImage(from: url) { [weak self] loadedImage in
            guard let self = self, let image = loadedImage else { return }
            self.image = image
        }
    }
}


//// Wrapper class to store an image along with its access date
//class CachedImage {
//    let image: UIImage
//    var lastAccessDate: Date
//
//    init(image: UIImage, lastAccessDate: Date = Date()) {
//        self.image = image
//        self.lastAccessDate = lastAccessDate
//    }
//}
