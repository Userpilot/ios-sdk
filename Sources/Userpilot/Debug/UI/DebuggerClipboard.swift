//
//  DebuggerClipboard.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

enum DebuggerClipboard {
    /// Copied values include tokens and user data, so they never sync to other devices and expire.
    static func copy(_ value: String, to pasteboard: UIPasteboard = .general) {
        pasteboard.setItems(
            [[plainTextType: value]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(expiration)]
        )
    }

    static let expiration: TimeInterval = 120

    private static let plainTextType = "public.utf8-plain-text"
}
