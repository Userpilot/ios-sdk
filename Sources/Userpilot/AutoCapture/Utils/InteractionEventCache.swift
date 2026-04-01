//
//  InteractionEventCache.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  High-frequency interactions (text field, text view, UISlider) are debounced per view via `EventDebounce`:
//  after each change, wait `interactionDebounceInterval` with no further changes, then send once.
//

import UIKit

internal enum InteractionEventCache {

    private static let debouncer = EventDebounce<InteractionPayload>(
        delay: AutoCaptureConstants.interactionDebounceInterval,
        deliveryQueue: .main
    ) { payload in
        guard Userpilot.isInitialized else { return }
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Schedules sending the interaction after `interactionDebounceInterval` of quiet time for this view.
    /// Each new call for the same view resets the timer and updates the payload to the latest.
    static func sendDebouncedInteraction(_ payload: InteractionPayload, for view: UIView) {
        guard Userpilot.isInitialized else { return }
        debouncer.schedule(key: debounceKey(for: view), value: payload)
    }

    /// Cancels pending debounced work (e.g. before a screen change).
    static func flushAll() {
        debouncer.cancelAll()
    }

    private static func debounceKey(for view: UIView) -> String {
        "interaction_debounce_\(ObjectIdentifier(view))"
    }
}
