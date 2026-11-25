//
//  CaptureMetadata.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines app, SDK, device and screen metadata saved with a capture.
//

import UIKit

// MARK: - App

/// Host application identity.
internal struct CaptureAppInfo: Encodable {

    let name: String
    let version: String
    let build: String
    let bundleID: String

    private typealias CodingKeys = Constants.BuilderCapture.Keys.App

    /// Reads the host app's own bundle. Not the SDK's bundle — under CocoaPods
    /// or SPM the SDK may be its own framework bundle, and the Builder needs to
    /// know which *app* was captured.
    init() {
        self.name = Bundle.main.displayName
        self.version = Bundle.main.version
        self.build = Bundle.main.build
        self.bundleID = Bundle.main.identifier
    }
}

// MARK: - SDK

/// Which SDK produced this capture.
internal struct CaptureSDKInfo: Encodable {

    private typealias CodingKeys = Constants.BuilderCapture.Keys.SDK

    let name: String
    let version: String

    /// Platform identifier in the shared capture schema.
    let platform: String

    init() {
        self.name = CaptureDocument.sdkName
        self.version = Userpilot.version()
        self.platform = CaptureDocument.platform
    }
}

// MARK: - Device

/// Device and OS context.
internal struct CaptureDeviceInfo: Encodable {

    let model: String
    let osName: String
    let osVersion: String
    let type: String
    let orientation: String
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Device

    /// Snapshots device metadata using the interface dimensions for orientation.
    init() {
        let bounds = UIScreen.main.bounds
        self.model = UIDevice.current.modelName
        self.osName = CaptureDocument.osName
        self.osVersion = UIDevice.current.systemVersion
        self.type = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "phone"
        self.orientation = bounds.width > bounds.height ? "landscape" : "portrait"
        self.screenWidth = bounds.width
        self.screenHeight = bounds.height
    }
}
