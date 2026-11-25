//
//  UIAccessibilityTraits+CaptureResolution.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Recognizes button-like accessibility traits used by SwiftUI title resolution.
//

import UIKit

internal extension UIAccessibilityTraits {
    /// Traits that mark an element as a clickable "button" for autocapture
    /// purposes. Capture is button-first: static text, headers, fields and
    /// containers never produce a resolver-supplied title.
    var userpilotContainsButtonLike: Bool {
        if contains(.button) || contains(.link) { return true }
        if #available(iOS 17.0, *), contains(.toggleButton) { return true }
        return false
    }
}
