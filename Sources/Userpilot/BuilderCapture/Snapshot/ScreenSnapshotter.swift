//
//  ScreenSnapshotter.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Renders the admitted host window at the capture coordinate scale.
//

import UIKit

// MARK: - Protocol

/// Renders a screenshot of the host app's UI.
internal protocol ScreenSnapshotting: AnyObject {

    /// Renders `window` to an image.
    ///
    /// Main thread only.
    ///
    /// - Returns: the rendered image, or `nil` when there was nothing to draw.
    func snapshot(of window: UIWindow) -> UserpilotScreenshot?
}

// MARK: - ScreenSnapshotter

/// `UIGraphicsImageRenderer`-based screenshot renderer.
internal final class ScreenSnapshotter: ScreenSnapshotting {

    // MARK: Nested Types

    private enum Constants {

        /// One pixel per point keeps screenshot pixels aligned with the element tree.
        static let logicalScale: CGFloat = 1
    }

    // MARK: Properties

    private let logger: Logging
    private let strategy: UserpilotElementTargetingStrategy

    // MARK: Initialization

    init(container: DIContainer) {
        self.strategy = container.resolve(UserpilotElementTargetingStrategy.self)
        self.logger = container.resolve(Userpilot.Config.self).logger
    }

    // MARK: ScreenSnapshotting

    /// Renders `window` at logical scale.
    ///
    /// `afterScreenUpdates: false` is kept on purpose. Passing
    /// `true` forces a layout/commit pass before drawing, which can run host-app
    /// layout code and animations mid-capture, and reliably makes the capture
    /// disagree with the element tree that was walked a moment earlier. Drawing
    /// the *already committed* frame is what keeps screenshot and tree in sync.
    ///
    /// `drawHierarchy`'s return value is logged but treated as **advisory**, not
    /// fatal. With `afterScreenUpdates: false` it also returns `false` for a
    /// hierarchy that simply has not rendered yet, so discarding the image on a
    /// `false` would throw away perfectly good captures. Logging it still earns
    /// its keep: it is the one
    /// signal that distinguishes a genuinely empty draw (an all-Metal screen)
    /// from a normal one.
    func snapshot(of window: UIWindow) -> UserpilotScreenshot? {
        let size = window.bounds.size

        // `UIGraphicsImageRenderer` throws on a zero-size format; the legacy
        // `UIGraphicsBeginImageContextWithOptions` merely misbehaved. Either way
        // there is nothing to capture.
        guard size.width > 0, size.height > 0 else {
            logger.error("📸 Screen capture failed: window has zero size")
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = Constants.logicalScale
        // Standard range keeps the PNG in sRGB. An extended-range (HDR) capture
        // would be larger and would not round-trip predictably through the
        // Builder's image pipeline.
        format.preferredRange = .standard

        if let screenshot = strategy.captureScreenshot?(in: window) {
            guard screenshot.isValid else { return nil }
            let image = UIGraphicsImageRenderer(size: screenshot.size, format: format).image { _ in
                screenshot.image.draw(in: CGRect(origin: .zero, size: screenshot.size))
            }
            return UserpilotScreenshot(image: image, size: screenshot.size, insets: screenshot.insets)
        }

        var drawSucceeded = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            drawSucceeded = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }

        if !drawSucceeded {
            logger.log("📸 Screen capture: hierarchy reported no image data; using it anyway")
        }

        return UserpilotScreenshot(image: image, size: size, insets: window.safeAreaInsets)
    }
}
