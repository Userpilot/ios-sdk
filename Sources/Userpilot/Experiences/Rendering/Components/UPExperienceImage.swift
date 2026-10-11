//
//  UPExperienceImage.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Bridges static and animated images through the existing image-loading service.
//

import SwiftUI

/// Each URL owns its image view so an old asynchronous request cannot replace a new component's image.
internal struct UPExperienceImage: View {
    let url: String
    let loader: ImageLoading
    var blurHash: String?
    var size = CGSize(width: 100, height: 100)
    var loadingSize: CGSize?
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var radius: CGFloat = 0
    var alt = ""

    var body: some View {
        ImageContent(url: url, loader: loader, blurHash: blurHash, size: loadingSize ?? size, contentMode: contentMode)
            .id(url)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .accessibility(label: Text(alt))
            .accessibility(hidden: alt.isEmpty)
    }

    /// Image pixels never dictate SwiftUI layout; the authored frame owns its size.
    private final class ImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }

    private struct ImageContent: UIViewRepresentable {
        let url: String
        let loader: ImageLoading
        let blurHash: String?
        let size: CGSize
        let contentMode: UIView.ContentMode

        func makeUIView(context: Context) -> ImageView {
            let imageView = ImageView()
            imageView.contentMode = contentMode
            imageView.clipsToBounds = true
            loader.loadImage(target: imageView, url: url, blurHash: blurHash, size: size)
            return imageView
        }

        func updateUIView(_ imageView: ImageView, context: Context) {
            imageView.contentMode = contentMode
        }

        static func dismantleUIView(_ imageView: ImageView, coordinator: ()) {
            imageView.stopAnimating()
        }
    }
}
