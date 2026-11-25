//
//  UIView+ExplicitRecognition.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Stores explicit interaction-recognition state without changing the public tagging API.
//

import UIKit

// MARK: - Private

private var explicitlyRecognizedKey: UInt8 = 0

// MARK: - Internal

/// Extension providing explicit recognition flag for UIView
internal extension UIView {
    // Internal flag to mark views that were explicitly recognized via the API
    // swiftlint:disable:next identifier_name
    var userpilot_isExplicitlyRecognized: Bool {
        get {
            return objc_getAssociatedObject(self, &explicitlyRecognizedKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &explicitlyRecognizedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
