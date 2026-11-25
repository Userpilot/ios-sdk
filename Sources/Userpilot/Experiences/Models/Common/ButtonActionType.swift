//
//  ButtonActionType.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines the action taken after an experience button is selected.
//

import Foundation

internal enum ButtonActionType: String, Codable {
    case doNothing = "do_nothing"
    case deepLink = "deep_link"
}
