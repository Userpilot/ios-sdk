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

/// Loads experience images without exposing downloading or caching to callers.
internal protocol ImageLoading: AnyObject {
    /// Uses an optional BlurHash placeholder; all image-view updates run on main.
    func loadImage(target: UIImageView, url: String, blurHash: String?, size: CGSize)
}

/// Owns per-instance caches and URLSession downloads. Image decoding lives on UIImage.
internal class ImageLoader: ImageLoading {

    /// Background reads of imageCache can overlap URLSession writes; decoding stays outside the lock.
    private let cacheLock = NSLock()
    /// Accessed only from the shared serial background queue.
    private var blurCache = [String: UIImage]()
    private var imageCache = [String: UIImage]()

    init(container: DIContainer) {
    }

    /// Reuses a cached URL first; otherwise displays the placeholder while the image downloads.
    func loadImage(target: UIImageView, url: String, blurHash: String?, size: CGSize) {
        performOn(.background) { [weak self] in
            guard
                let self,
                let url = URL(string: url)
            else { return }

            if let image = cacheLock.withLock({ self.imageCache[url.absoluteString] }) {
                setImage(target, image)
                return
            }

            if let blurHash, let image = blurImage(for: blurHash) {
                setImage(target, image)
            }

            self.loadImage(from: url, size: size) { [weak self] image in
                guard let image else { return }
                self?.setImage(target, image)
            }
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

    /// Placeholders and downloaded images share the same existing crossfade behavior.
    private func setImage(_ target: UIImageView, _ image: UIImage) {
        performOn(.main) { [weak self] in
            guard self != nil else { return }
            target.setImageWithCrossfade(image)
        }
    }

    /// Decodes outside the lock, then stores the image before notifying the caller.
    private func loadImage(from url: URL, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, error in
            guard let self, let data = data, error == nil else {
                completion(nil)
                return
            }
            let image = UIImage.decoded(from: data, size: size)
            if let image {
                self.cacheLock.withLock { self.imageCache[url.absoluteString] = image }
            }
            completion(image)
        }.resume()
    }
}
