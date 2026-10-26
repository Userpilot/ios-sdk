//
//  ImageLoader.swift
//  Userpilot SDK
//
//  Created by Userpilot on 03/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Loads static images and GIFs with optional BlurHash placeholders. Each loader
//  owns its image caches; downloading and decoding run off main, with image-view
//  updates dispatched to main.
//

import Foundation
import UIKit

/// One image load. `cancel()` stops its download and drops anything not yet delivered; safe from any thread.
internal final class ImageLoadTask {
    private let lock = NSLock()
    private var cancelled = false
    private var dataTask: URLSessionDataTask?

    var isCancelled: Bool { lock.withLock { cancelled } }

    func cancel() {
        let running = lock.withLock { () -> URLSessionDataTask? in
            cancelled = true
            return dataTask
        }
        running?.cancel()
    }

    /// Keeps the download so a later `cancel()` can stop it. False (and the download is cancelled)
    /// when the load was already cancelled.
    func attach(_ task: URLSessionDataTask) -> Bool {
        let wasCancelled = lock.withLock { () -> Bool in
            if !cancelled { dataTask = task }
            return cancelled
        }
        if wasCancelled { task.cancel() }
        return !wasCancelled
    }
}

/// Loads experience images without exposing downloading or caching to callers.
internal protocol ImageLoading: AnyObject {
    /// Delivers the BlurHash placeholder first (when there is one and the image isn't cached),
    /// then the decoded image with `isFinal` true. Every call runs on main. Cancel the returned task
    /// when the image is no longer needed.
    @discardableResult
    func loadImage(
        url: String, blurHash: String?, size: CGSize, completion: @escaping (UIImage, _ isFinal: Bool) -> Void
    ) -> ImageLoadTask
    /// The decoded image for `url` when it is already in memory and covers `size`, read synchronously.
    func cachedImage(url: String, size: CGSize) -> UIImage?
}

/// Owns per-instance caches and URLSession downloads. Image decoding lives on UIImage.
internal class ImageLoader: ImageLoading {

    /// Background reads of imageCache can overlap URLSession writes; decoding stays outside the lock.
    private let cacheLock = NSLock()
    /// Accessed only from the shared serial background queue.
    private var blurCache = [String: UIImage]()
    /// One decode per URL, with the box it was decoded for, so a larger box isn't served an upscaled image.
    private var imageCache = [String: CachedImage]()

    private struct CachedImage {
        let image: UIImage
        let box: CGSize

        func covers(_ size: CGSize) -> Bool {
            box.width >= size.width - 0.5 && box.height >= size.height - 0.5
        }
    }

    init(container: DIContainer) {
    }

    @discardableResult
    func loadImage(
        url: String, blurHash: String?, size: CGSize, completion: @escaping (UIImage, Bool) -> Void
    ) -> ImageLoadTask {
        let task = ImageLoadTask()
        performOn(.background) { [weak self] in
            // Cancelled before the background queue got to it: start nothing.
            guard let self, !task.isCancelled, let url = URL(string: url) else { return }
            if let cached = cacheLock.withLock({ self.imageCache[url.absoluteString] }), cached.covers(size) {
                deliver(cached.image, isFinal: true, task: task, to: completion)
                return
            }
            if let blurHash, let image = blurImage(for: blurHash) {
                deliver(image, isFinal: false, task: task, to: completion)
            }
            self.loadImage(from: url, size: size, task: task) { [weak self] image in
                guard let image else { return }
                self?.deliver(image, isFinal: true, task: task, to: completion)
            }
        }
        return task
    }

    func cachedImage(url: String, size: CGSize) -> UIImage? {
        guard let url = URL(string: url) else { return nil }
        return cacheLock.withLock { imageCache[url.absoluteString] }.flatMap { $0.covers(size) ? $0.image : nil }
    }

    private func deliver(
        _ image: UIImage, isFinal: Bool, task: ImageLoadTask, to completion: @escaping (UIImage, Bool) -> Void
    ) {
        performOn(.main) { [weak self] in
            // A load cancelled while this hop was queued delivers nothing.
            guard self != nil, !task.isCancelled else { return }
            completion(image, isFinal)
        }
    }

    /// Placeholder decoding and caching stay on the caller's serial background queue.
    private func blurImage(for blurHash: String) -> UIImage? {
        if let image = blurCache[blurHash] { return image }
        guard let image = UIImage(blurHash: blurHash, size: ThemeHandler.DefaultValues.blurImageSize) else {
            return nil
        }
        blurCache[blurHash] = image
        return image
    }

    /// Decodes outside the lock, then stores the image before notifying the caller.
    private func loadImage(
        from url: URL, size: CGSize, task: ImageLoadTask, completion: @escaping (UIImage?) -> Void
    ) {
        let download = URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, error in
            // A cancelled download ends with an error; one cancelled just after arriving isn't decoded.
            guard let self, let data = data, error == nil, !task.isCancelled else {
                completion(nil)
                return
            }
            let image = UIImage.decoded(from: data, size: size)
            if let image {
                self.cacheLock.withLock { self.imageCache[url.absoluteString] = CachedImage(image: image, box: size) }
            }
            completion(image)
        }
        // The task keeps the download, so cancelling the load stops the network request itself.
        guard task.attach(download) else { return }
        download.resume()
    }
}
