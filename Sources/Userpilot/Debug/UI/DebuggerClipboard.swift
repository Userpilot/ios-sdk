//
//  DebuggerClipboard.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

enum DebuggerClipboard {
    static func copy(_ value: String) {
        UIPasteboard.general.string = value
    }
}
