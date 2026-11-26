//
//  CaptureScreenInfo.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The capture document's `screen` object: the last screen event as the SDK sent it, plus the `name`
//  Appex uses to link the capture to a tagged screen.
//

import Foundation

// MARK: - Screen

/// The last `screen` event's `title` and `metadata`, unchanged, plus `name` set to the same title.
/// `native_controller` and `route` from the contract are not sent.
internal struct CaptureScreenInfo: Encodable {

    /// The screen event's title, cut at `Constants.BuilderCapture.maxNameLength` code points.
    let name: String

    /// The screen event's title as sent.
    let title: String

    /// The screen event's metadata as sent.
    let metadata: [String: Any]

    private typealias CodingKeys = Constants.BuilderCapture.Keys.Screen

    init(_ screen: ScreenPayload) {
        self.name = CaptureDocument.cappedName(screen.title)
        self.title = screen.title
        self.metadata = screen.metadata
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encodePayloadIfPresent(metadata, forKey: .metadata)
    }
}
