//
//  ThemeStyleTypes.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines shared theme style choices.
//

import Foundation
import UIKit

internal enum ProgressStyleType: String, Codable {
    case bar
    case ball
    /// A Flow theme's dots, drawn like `ball`.
    case dots
    /// A Flow theme's `{position} of {steps_count}` text, drawn where the dots go.
    case counter
}

internal enum ColorType: String, Codable {
    case manual
    case automatic
}
