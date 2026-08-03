//
//  UPDisplayCornerRadius.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The display's corner radius — measured, because iOS will not tell us.
//

import UIKit

/// Supplies the radius a card needs in order to look concentric with the display's own corners,
/// as a number the SDK can then reuse.
///
/// Apple's `UICornerRadius.containerConcentric` renders this correctly, but its resolved value is
/// not readable: `cornerConfiguration` exposes no radii and `layer.cornerRadius` stays `0`. The SDK
/// needs the number, because every card it draws has the dimming backdrop cut to the card's shape,
/// and a hole cut from a different radius than the card leaves undimmed content showing through
/// outside the card's corners — see Q7 in the iOS 26 spike.
///
/// So it is measured: a small probe with concentric corners is rasterised, and the corner arc is
/// located along its 45° diagonal. `layer.render(in:)` honours `cornerConfiguration`, so this needs
/// no private API. Checked against `UIScreen._displayCornerRadius` at three insets in
/// Verified during the iOS 26 spike: 62/42/32 expected, 62.6/42.1/31.9 measured.
///
/// Absolute accuracy matters less than it looks: the card and its backdrop hole are built from the
/// *same* returned value, so any measurement error moves both together and they still agree
/// exactly. The measurement only has to be close enough to read as concentric.
internal enum UPDisplayCornerRadius {

    /// Probe size. Only its bottom-left corner is measured, so it needs to be big enough to
    /// contain the largest plausible display curvature and nothing more.
    private static let probeSide: CGFloat = 140

    /// Along a 45° diagonal from the corner, a circular arc of radius `r` is crossed at
    /// `t = r(1 - 1/√2)`.
    private static let diagonalArcFactor: CGFloat = 1 - 1 / 2.0.squareRoot()

    /// Measured radii, keyed by screen geometry — this is a property of the hardware, not of any
    /// view, so one measurement per device per process is enough.
    private static var cache: [String: CGFloat] = [:]

    // MARK: Public

    /// The radius a card should use when it is inset from the display's edges.
    ///
    /// - Parameters:
    ///   - displayRadius: Measured display corner radius, or `nil` if it could not be measured.
    ///   - inset: How far the card sits in from the display edge.
    ///   - minimum: Floor for the result — the customer's configured radius, never discarded.
    /// - Returns: `displayRadius - inset`, floored at `minimum`. Falls back to `minimum` alone when
    ///   there is no measurement, or on a display with square corners.
    static func concentricRadius(
        displayRadius: CGFloat?,
        inset: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        guard let displayRadius, displayRadius > 0 else { return minimum }
        return max(minimum, displayRadius - inset)
    }

    /// The display corner radius behind `container`, or `nil` when it cannot be measured.
    ///
    /// Returns `nil` rather than a guess when the container is not yet in a window: concentric
    /// corners have no display to resolve against until then. Callers should ask again after
    /// layout, which is when the answer becomes available.
    static func measured(in container: UIView) -> CGFloat? {
        guard let key = cacheKey(for: container) else { return nil }
        if let cached = cache[key] { return cached }
        guard let measured = measure(in: container) else { return nil }
        cache[key] = measured
        return measured
    }

    // MARK: Private

    private static func cacheKey(for container: UIView) -> String? {
        guard let window = container.window else { return nil }
        let size = window.bounds.size
        return "\(Int(size.width))x\(Int(size.height))@\(container.traitCollection.displayScale)"
    }

    /// Rasterises a probe pinned to the container's bottom-left corner and reads the arc back.
    ///
    /// The `#if compiler(>=6.2)` gate is what keeps this compiling on Xcode versions without the
    /// iOS 26 SDK, where `cornerConfiguration` does not exist.
    private static func measure(in container: UIView) -> CGFloat? {
        #if compiler(>=6.2)
        guard #available(iOS 26.0, *) else { return nil }
        guard container.window != nil,
              container.bounds.width >= probeSide,
              container.bounds.height >= probeSide
        else { return nil }

        let probe = UIView(
            frame: CGRect(
                x: 0,
                y: container.bounds.height - probeSide,
                width: probeSide,
                height: probeSide
            )
        )
        probe.backgroundColor = .black
        probe.isUserInteractionEnabled = false
        // `minimum: 0` so the result is the display's own curvature, unclamped.
        probe.cornerConfiguration = .corners(radius: .containerConcentric(minimum: 0))
        container.addSubview(probe)

        let scale = max(container.traitCollection.displayScale, 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: probe.bounds, format: format).image { context in
            probe.layer.render(in: context.cgContext)
        }
        probe.removeFromSuperview()

        return radiusOfBottomLeftCorner(of: image, scale: scale)
        #else
        return nil
        #endif
    }

    /// Walks in from the bottom-left corner along the 45° diagonal and converts the first covered
    /// pixel into a radius. Returns `nil` if nothing was drawn, `0` for a square corner.
    private static func radiusOfBottomLeftCorner(of image: UIImage, scale: CGFloat) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Row 0 of a `CGImage` is the top, so the bottom-left corner is (0, height - 1).
        for step in 0..<min(width, height) {
            let offset = (height - 1 - step) * bytesPerRow + step * 4
            guard pixels[offset + 3] > 200 else { continue }
            // Half a pixel back: the arc crosses somewhere inside the first covered pixel.
            let distance = (CGFloat(step) - 0.5) / scale
            return max(0, distance / diagonalArcFactor)
        }
        return nil
    }
}
