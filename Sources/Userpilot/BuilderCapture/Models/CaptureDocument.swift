//
//  CaptureDocument.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines `capture.json`, the uploaded capture document, and its screenshot coordinate schema.
//

import UIKit

// MARK: - Capture Document

/// One captured screen, encoded in memory as the upload's `capture.json`. Nothing is written to disk.
internal struct CaptureDocument: Encodable {

    /// Version of *this document's* shape, so a Builder reading an old capture
    /// knows what to expect. Unrelated to `ElementSelector.selectorVersion`,
    /// which versions the scoring contract.
    let schemaVersion: Int

    /// The QR link's `capture_id`, equal to the upload's `capture_id` part. One QR code, one capture.
    let captureID: String

    /// When the capture was taken, ISO 8601.
    let capturedAt: String

    /// The confirmation sheet's name, trimmed and cut at `maxNameLength` code points; the screen title
    /// until Save. Set it through `named(_:)`, which applies both rules.
    var displayName: String

    /// Host application identity.
    let app: CaptureAppInfo

    /// Which SDK produced the capture.
    let sdk: CaptureSDKInfo

    /// Device and OS the capture was taken on.
    let device: CaptureDeviceInfo

    /// The last screen event plus its `name`; a capture needs a tracked screen.
    let screen: CaptureScreenInfo

    /// Coordinate contract between the screenshot and the element tree.
    let viewport: CaptureViewport

    /// The screenshot part's file name and size.
    let screenshot: CaptureScreenshotInfo

    /// The captured view hierarchy.
    let elementTree: ElementNode

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Document

    /// This document with the confirmation sheet's `name` as `display_name`; a blank name keeps the current one.
    func named(_ name: String) -> CaptureDocument {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        var named = self
        named.displayName = Self.cappedName(trimmed)
        return named
    }
}

// MARK: - Constants

internal extension CaptureDocument {

    /// Current document shape version.
    static let schemaVersion = Constants.BuilderCapture.documentSchemaVersion

    /// Identifies this SDK to the Builder.
    static let sdkName = "userpilot-ios"

    static let osName = "ios"

    /// Platform identifier in the shared capture schema.
    static let platform = "ios"

    /// Element-tree rects and screenshot pixels share one space.
    static let coordinateSpace = "screenshot_logical"

    static let coordinateUnit = "points"

    static let screenshotFormat = "png"

    /// Formats `captured_at`. Built per call rather than cached: captures are a
    /// rare, operator-driven action, so there is nothing to optimise and a
    /// shared mutable formatter would need synchronising.
    static func timestamp(for date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// Longest `display_name` and `screen.name`, in Unicode code points.
    static let maxNameLength = Constants.BuilderCapture.maxNameLength

    /// Cuts `name` at `maxNameLength` Unicode code points, so both platforms cut a name at the same place.
    static func cappedName(_ name: String) -> String {
        guard name.unicodeScalars.count > maxNameLength else { return name }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: name.unicodeScalars.prefix(maxNameLength))
        return String(scalars)
    }
}
