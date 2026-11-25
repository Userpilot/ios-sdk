//
//  CaptureSession.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  One Builder capture session opened from a QR capture link.
//

import Foundation

/// One Builder session, owned on main by `BuilderCaptureCoordinator`. Identity comparisons reject
/// callbacks from a replaced session. No description: it holds the Builder credential.
internal final class CaptureSession {
    let captureID: String
    /// Refreshed when the same QR code is opened again; read at send time.
    private(set) var token: CaptureToken

    init(_ link: CaptureLink) {
        captureID = link.captureID
        token = link.token
    }

    /// Takes the newer token of a link with this session's capture id.
    func refresh(with link: CaptureLink) {
        guard link.captureID == captureID else { return }
        token = link.token
    }
}
