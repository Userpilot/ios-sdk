//
//  UIWindow+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Identifies SDK-owned overlays when selecting an application window.
//

import UIKit

internal extension UIWindow {
    /// `true` when this window is an internal Userpilot SDK overlay.
    ///
    /// Keeps `ExperienceOverlayWindow`'s scene resolver from selecting an SDK overlay
    /// as the fallback application host.
    var isUserpilotWindow: Bool {
        return self is ExperienceOverlayWindow || self is DebugUIWindow
    }
}
