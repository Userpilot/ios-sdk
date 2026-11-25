//
//  CaptureUpload.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Describes one prepared capture upload: the capture id and the encoded PNG and capture.json bytes.
//

import Foundation

/// One confirmed capture ready to send, held in memory only. It carries no token, URL or per-key fields,
/// so it is safe to keep for Retry; every attempt sends these same bytes under the same capture id.
internal struct CaptureUpload {

    /// The QR link's `capture_id`, sent as the `capture_id` text part.
    let captureID: String

    /// Encoded PNG, sent as the `screenshot` file part.
    let screenshot: Data

    /// Encoded `capture.json`, sent as the `document` file part.
    let document: Data
}
