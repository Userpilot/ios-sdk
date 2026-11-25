//
//  SelectorKeys.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Wire names owned by native targeting, separate from analytics text.
//

internal enum SelectorKeys: String, CodingKey {
    case userpilotID = "userpilot_id"
    case autoTag = "auto_tag"
    case tag

    enum Envelope: String, CodingKey {
        case selectorVersion = "selector_version"
        case platform
        case toolkit
        case properties
        case constraints
        case minimumScore = "minimum_score"
        case onAmbiguous = "on_ambiguous"
    }

    enum Constraints: String, CodingKey {
        case role
        case nativeType = "native_type"
        case screenName = "screen_name"
    }
}
