//
//  StoredOfflineEventKind.swift
//  Userpilot SDK
//
//  Created by Userpilot on 21/09/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Which pipeline a stored offline row came from.
//

import Foundation

/// Which pipeline a stored offline row came from.
///
/// The raw values are persisted and sent in offline batches; renaming them requires
/// a storage migration and compatibility with the backend batch contract.
internal enum StoredOfflineEventKind: String, Codable {
    case analytics
    /// `internal` is a Swift keyword, so the case is spelled differently from its raw value.
    case internalEvent = "internal"
}
