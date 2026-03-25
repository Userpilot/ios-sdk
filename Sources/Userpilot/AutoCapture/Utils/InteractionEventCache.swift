//
//  InteractionEventCache.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  InteractionEventCache provides utilities for caching hight frequency events and send
//  them when screen changed.
//

import UIKit

// MARK: - Interaction Event Cache

/// Caches one pending interaction payload per view instance.
/// Used for high-frequency interactions (text input, slider drag)
/// where we only want one event with the final value.
/// Flushed when the screen changes (new screen tracked).
internal enum InteractionEventCache {

    /// Pending payloads keyed by the view's ObjectIdentifier
    private(set) static var pendingEvents: [ObjectIdentifier: InteractionPayload] = [:]

    /// Upserts a payload into the cache for the given view
    static func upsert(_ payload: InteractionPayload, for view: UIView) {
        pendingEvents[ObjectIdentifier(view)] = payload
    }

    /// Flushes all cached events, sending them via the engine, then clears the cache
    static func flushAll() {
        guard !pendingEvents.isEmpty else { return }
        guard Userpilot.isInitialized else { pendingEvents.removeAll(); return }

        let events = pendingEvents
        pendingEvents.removeAll()

        for (_, payload) in events {
            Userpilot.shared.uiKitAutoCaptureEngine.handleInteraction(payload)
        }
    }
}
