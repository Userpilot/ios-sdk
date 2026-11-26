//
//  Constants+BuilderCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns nested capture-document keys, capture link names and upload request values without changing
//  native model property names.
//

import Foundation

extension Constants {
    enum BuilderCapture {
        /// Capture document version, independent of selector scoring versions.
        static let documentSchemaVersion = 1
        /// Longest `display_name` and `screen.name`, counted in Unicode code points on both platforms.
        static let maxNameLength = 255

        static let encoderQueueLabel = "com.userpilot.capture-encoder-queue"
    }
}

extension Constants.BuilderCapture {
    enum Keys {}

    /// The QR deep link `userpilot-{app_token}://sdk/capture?capture_id=…&token=…`;
    /// `CaptureLink.Field` names its query items.
    enum Link {
        /// The single path segment after the `sdk` host.
        static let route = "capture"
    }

    /// Multipart upload of one confirmed capture: `capture_id`, `screenshot` and `document` parts.
    enum Upload {
        static let captureIDPart = "capture_id"
        static let screenshotPart = "screenshot"
        static let documentPart = "document"
        static let screenshotFileName = "screenshot.png"
        static let documentFileName = "capture.json"
        static let screenshotContentType = "image/png"
        static let documentContentType = "application/json"
        /// A larger PNG is not sent; one exactly at the limit is.
        static let maxScreenshotBytes = 5_000_000
        /// A larger `capture.json` is not sent; one exactly at the limit is.
        static let maxDocumentBytes = 2_000_000
        /// Total time for one attempt, including the body upload; the progress dialog has no Cancel.
        static let requestTimeout: TimeInterval = 30
        static let backgroundTaskName = "Userpilot capture upload"
    }
}

extension Constants.BuilderCapture.Keys {
    enum Document: String, CodingKey {
        case schemaVersion = "schema_version"
        case captureID = "capture_id"
        case capturedAt = "captured_at"
        case displayName = "display_name"
        case app
        case sdk
        case device
        case screen
        case viewport
        case screenshot
        case elementTree = "element_tree"
    }

    enum Screen: String, CodingKey {
        case name
        case title
        case metadata
    }

    enum App: String, CodingKey {
        case name
        case version
        case build
        case bundleID = "bundle_id"
    }

    enum Device: String, CodingKey {
        case model
        case osName = "os_name"
        case osVersion = "os_version"
        case type
        case orientation
        case screenWidth = "screen_width"
        case screenHeight = "screen_height"
    }

    enum Viewport: String, CodingKey {
        case coordinateSpace = "coordinate_space"
        case unit
        case pixelRatio = "pixel_ratio"
        case width
        case height
        case safeAreaInsets = "safe_area_insets"
    }

    enum Screenshot: String, CodingKey {
        case fileName = "file_name"
        case format
        case widthPx = "width_px"
        case heightPx = "height_px"
    }

    enum Node: String, CodingKey {
        case nodeID = "node_id"
        case bounds
        case visibleBounds = "visible_bounds"
        case selector
        case children
    }

    enum Rect: String, CodingKey {
        case posX = "x"
        case posY = "y"
        case width
        case height
    }

    enum SDK: String, CodingKey {
        case name, version, platform
    }

    enum Insets: String, CodingKey {
        case top, left, bottom, right
    }
}
