//
//  CaptureScreenshotInfo.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines the uploaded screenshot's file name, format and dimensions.
//

import UIKit

// MARK: - Screenshot

/// The screenshot part's file name and how big the image is.
internal struct CaptureScreenshotInfo: Encodable {

    /// Always `screenshot.png`, the multipart file name of the `screenshot` part.
    let fileName: String

    /// Always `png`.
    let format: String

    let widthPx: Int
    let heightPx: Int

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Screenshot

    /// Uses actual bitmap dimensions; logical size and scale are fallbacks when unavailable.
    init(
        pixelWidth: Int?,
        pixelHeight: Int?,
        logicalSize: CGSize,
        scale: CGFloat
    ) {
        self.fileName = Constants.BuilderCapture.Upload.screenshotFileName
        self.format = CaptureDocument.screenshotFormat
        self.widthPx = pixelWidth ?? Int((logicalSize.width * scale).rounded(.up))
        self.heightPx = pixelHeight ?? Int((logicalSize.height * scale).rounded(.up))
    }
}
