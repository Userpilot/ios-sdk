//
//  ElementPropertyKeys.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns element wire names shared by targeting and analytics without feature state.
//

internal enum ElementPropertyKeys: String, CodingKey {
    case targetClass = "target_class"
    case targetText = "target_text"
    case accessibilityIdentifier = "accessibility_identifier"
    case accessibilityLabel = "accessibility_label"
    case targetResourceID = "target_resource_id"
    case viewTag = "view_tag"
}
