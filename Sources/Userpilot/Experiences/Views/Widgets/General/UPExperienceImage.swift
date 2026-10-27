//
//  UPExperienceImage.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Draws experience images in SwiftUI, with a plain UIImageView only for animated images.
//

import SwiftUI

/// The downloaded content decides what draws the pixels: SwiftUI `Image` for a still image or its
/// placeholder, a plain `UIImageView` for an animated image. Size, clipping and alt text are shared.
internal struct UPExperienceImage: View {
    /// Reduce Motion shows an animated image's first frame instead of playing it, and updates live.
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: UPImageModel
    var size = CGSize(width: 100, height: 100)
    /// `object_fit: fill` stretches to the box, as `scaleToFill` did; anything else fits.
    var stretches = false
    /// Fills the box at the image's own aspect and crops the rest, as list-line icons do on Android.
    var fills = false
    var radius: CGFloat = 0
    var alt = ""

    var body: some View {
        ZStack {
            // Keeps the frame a real view before any pixels arrive, so it appears and starts the download.
            Color.clear
            if let image = model.image {
                pixels(image).transition(.opacity)
            } else if let placeholder = model.placeholder {
                pixels(placeholder).transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        // The download runs while the image is on screen (`.task` needs iOS 15).
        .onAppear { model.viewAppeared() }
        .onDisappear { model.viewDisappeared() }
        // One VoiceOver element read by its alt text; an image without alt text is treated as decorative.
        .accessibilityElement(children: .ignore)
        .accessibility(label: Text(verbatim: alt))
        .accessibility(addTraits: .isImage)
        .accessibility(hidden: alt.isEmpty)
    }

    @ViewBuilder
    private func pixels(_ image: UIImage) -> some View {
        if let frames = image.images, frames.count > 1 {
            UPAnimatedImageView(image: reduceMotion ? frames[0] : image, stretches: stretches, fills: fills)
        } else if stretches {
            Image(uiImage: image).resizable()
        } else if fills {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        } else {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
        }
    }
}

/// SwiftUI can't animate an image on any iOS version; `UIImageView` plays the frames in Core Animation.
private struct UPAnimatedImageView: UIViewRepresentable {
    let image: UIImage
    let stretches: Bool
    let fills: Bool

    func makeUIView(context: Context) -> ImageView {
        let view = ImageView()
        view.clipsToBounds = true
        // Smart Invert must not negate photos and illustrations.
        view.accessibilityIgnoresInvertColors = true
        return view
    }

    func updateUIView(_ view: ImageView, context: Context) {
        view.contentMode = stretches ? .scaleToFill : fills ? .scaleAspectFill : .scaleAspectFit
        if view.image !== image { view.image = image }
    }

    static func dismantleUIView(_ view: ImageView, coordinator: ()) {
        view.stopAnimating()
    }

    /// Pixels never dictate SwiftUI layout; the authored frame owns the size.
    final class ImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }
}
