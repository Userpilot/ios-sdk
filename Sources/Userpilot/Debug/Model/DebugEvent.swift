//
//  DebugEvent.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// UI-ready analytics or SDK event.
///
/// Properties are pre-flattened and truncated so list binding never walks raw maps.
internal struct DebugEvent: Equatable {
    let id: Int
    let channel: DebugEventChannel
    let title: String
    let typeLabel: String
    let timestampMs: Int64
    let properties: [DebugProperty]
}
