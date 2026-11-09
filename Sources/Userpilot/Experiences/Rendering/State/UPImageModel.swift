//
//  UPImageModel.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  One image's placeholder and final pixels, owned by the render state so redraws never reload it.
//

import SwiftUI

/// One image's pixels. The render state owns it, so SwiftUI re-evaluation never restarts its download.
///
/// The download runs only while a view shows the image, the iOS 13 equivalent of SwiftUI's `.task`
/// (iOS 15+): the first view to appear starts it, and when the last one disappears an unfinished
/// download stops. Releasing the model, when the experience closes, stops it too.
internal final class UPImageModel: ObservableObject {
    @Published private(set) var placeholder: UIImage?
    @Published private(set) var image: UIImage?
    private let url: String
    private let blurHash: String?
    private let size: CGSize
    private let loader: ImageLoading
    private var task: ImageLoadTask?
    /// Views showing this image right now; the same image can appear in more than one place.
    private var visibleViews = 0

    /// Reads the memory cache synchronously, so a cached image shows on the first frame.
    init(url: String, blurHash: String?, size: CGSize, loader: ImageLoading) {
        self.url = url
        self.blurHash = blurHash
        self.size = size
        self.loader = loader
        image = loader.cachedImage(url: url, size: size)
    }

    deinit { task?.cancel() }

    /// Starts the download, unless the image is already here or on its way.
    func viewAppeared() {
        visibleViews += 1
        guard image == nil, task == nil else { return }
        task = loader.loadImage(url: url, blurHash: blurHash, size: size) { [weak self] image, isFinal in
            guard let self else { return }
            if isFinal {
                self.task = nil
                withAnimation(.easeInOut(duration: 0.3)) { self.image = image }
            } else if self.image == nil {
                // A placeholder that arrives late never replaces the real image.
                self.placeholder = image
            }
        }
    }

    /// Stops an unfinished download once no view shows the image.
    func viewDisappeared() {
        visibleViews = max(0, visibleViews - 1)
        guard visibleViews == 0 else { return }
        task?.cancel()
        task = nil
    }
}
