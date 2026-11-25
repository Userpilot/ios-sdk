//
//  ButtonAction.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines an authored flow button action.
//

import Foundation
import UIKit

// MARK: - ButtonAction

/// What a step's button does: its `button_action`, and the iOS deep link a `link` action opens.
internal struct ButtonAction: Codable {
    let buttonAction: String?
    let deepLink: String?

    private enum CodingKeys: String, CodingKey {
        case buttonAction = "button_action"
        case deepLink = "ios_deep_link"
    }

    /// `link` opens `deepLink`; any other action advances. A Flow opens it from its last step only.
    var isLink: Bool {
        buttonAction == "link"
    }
}
