//
//  DebuggerClipboard.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

enum DebuggerClipboard {
    static func copy(_ value: String) {
        UIPasteboard.general.string = value
    }
}
