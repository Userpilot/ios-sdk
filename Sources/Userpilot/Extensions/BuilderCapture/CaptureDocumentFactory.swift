//
//  CaptureDocumentFactory.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Assembles immutable capture metadata from the admitted host.
//

import UIKit

// MARK: - Document Assembly

internal extension CaptureDocument {

    /// Builds the document for one capture.
    ///
    /// Two values here are the coordinate contract between the screenshot and
    /// the element tree, and both are read from the image that was *actually*
    /// produced rather than assumed:
    ///
    /// * `pixel_ratio` comes from `screenshot.image.scale`, so if the renderer ever
    ///   stops honouring logical scale the document says so instead of lying.
    /// * `width_px` / `height_px` come from the backing bitmap. The renderer
    ///   rounds a fractional size **up** to whole pixels, so computing
    ///   `size * scale` would under-report by a pixel whenever the window has a
    ///   fractional width — routine in iPad Split View and Slide Over — and the
    ///   Builder would map clicks against an image narrower than the real one.
    ///
    /// - Parameters:
    ///   - captureID: the QR link's `capture_id`.
    ///   - screenshot: the rendered screen.
    ///   - elementTree: the tree read from the same admitted window.
    ///   - screen: the original screen-session event, without analytics-only decorations. Its title is the
    ///     suggested `display_name` until the operator saves another name.
    static func make(
        captureID: String,
        screenshot: UserpilotScreenshot,
        elementTree: ElementNode,
        screen: ScreenPayload
    ) -> CaptureDocument {
        CaptureDocument(
            schemaVersion: CaptureDocument.schemaVersion,
            captureID: captureID,
            capturedAt: CaptureDocument.timestamp(for: Date()),
            displayName: "",
            app: CaptureAppInfo(),
            sdk: CaptureSDKInfo(),
            device: CaptureDeviceInfo(),
            screen: CaptureScreenInfo(screen),
            viewport: CaptureViewport(
                size: screenshot.size,
                pixelRatio: screenshot.image.scale,
                safeAreaInsets: screenshot.insets
            ),
            screenshot: CaptureScreenshotInfo(
                pixelWidth: screenshot.image.cgImage?.width,
                pixelHeight: screenshot.image.cgImage?.height,
                logicalSize: screenshot.size,
                scale: screenshot.image.scale
            ),
            elementTree: elementTree
        ).named(screen.title)
    }
}
