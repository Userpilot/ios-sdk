//
//  DebugEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  UI-ready analytics or SDK event.
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
