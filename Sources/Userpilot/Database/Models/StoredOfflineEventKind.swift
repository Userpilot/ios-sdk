//
//  StoredOfflineEventKind.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Which pipeline a stored offline row came from.
//

import Foundation

/// Which pipeline a stored offline row came from.
///
/// The raw values are a cross-platform contract with the Android SDK's
/// `StoredOfflineEventKind` — do not rename them without changing both.
internal enum StoredOfflineEventKind: String, Codable {
    case analytics
    /// `internal` is a Swift keyword, so the case is spelled differently from its raw value.
    case internalEvent = "internal"
}
