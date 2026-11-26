//
//  CaptureLink.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The validated values of one Builder QR capture link. Its descriptions never show the token.
//

import Foundation

/// One scanned QR code created for iOS: `capture_id` and the short-lived token. Built only through
/// `from(captureID:platform:token:)`, so every instance passed all checks.
internal struct CaptureLink: Hashable {

    /// A link value, named by its query item; the only part of a rejected link that is logged.
    enum Field: String, CaseIterable {
        case captureID = "capture_id"
        case platform
        case token
    }

    private static let otherPlatform = "android"

    let captureID: String
    let token: CaptureToken

    private init(captureID: String, token: CaptureToken) {
        self.captureID = captureID
        self.token = token
    }

    /// Nil when any value is missing or blank, or the platform is not iOS.
    static func from(captureID: String?, platform: String?, token: String?) -> CaptureLink? {
        guard invalidField(captureID: captureID, platform: platform, token: token) == nil,
              let captureID, let token = CaptureToken(token) else { return nil }
        return CaptureLink(captureID: captureID, token: token)
    }

    /// The first missing, blank or wrong value, checked in link order; nil for a valid link.
    static func invalidField(captureID: String?, platform: String?, token: String?) -> Field? {
        guard let captureID, !captureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .captureID
        }
        guard platform?.lowercased() == CaptureDocument.platform else { return .platform }
        guard CaptureToken(token) != nil else { return .token }
        return nil
    }

    /// True when `platform` names Android: the QR code was created for the other operating system.
    static func isForOtherPlatform(_ platform: String?) -> Bool {
        platform?.lowercased() == otherPlatform
    }
}

// MARK: - Redacted descriptions

extension CaptureLink: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "CaptureLink(<redacted>)" }
    var debugDescription: String { description }
    /// `dump` and debugger mirrors would otherwise list the link's values.
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
