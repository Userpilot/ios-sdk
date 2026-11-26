//
//  ScreenPayload.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shares original screen title and metadata between analytics and Builder capture.
//

import Foundation

/// Pure screen-event content. Reading it does not prepare a session or decorate analytics metadata.
internal struct ScreenPayload: Encodable {
    let title: String
    let metadata: [String: Any]

    init(event: Event) {
        title = event.screenTitle ?? ""
        metadata = event.properties ?? [:]
    }

    /// Analytics alone supplies its session flags and seen-content snapshot.
    func toDictionary(adding metadata: [String: Any] = [:]) -> [String: Any] {
        [Constants.Analytics.screenTitleProperty: title,
         Constants.Analytics.metaDataProperty: self.metadata.merging(metadata) { _, new in new }]
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case metadata
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodePayloadIfPresent(metadata, forKey: .metadata)
    }
}
