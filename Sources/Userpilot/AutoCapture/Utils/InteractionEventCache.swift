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
//  For text inputs, if `text_length` matches the last delivered event for that field, the new notification
//  is ignored (e.g. spurious `textDidChange` when tapping another control). Last length is updated when the
//  debounced delivery runs on the main queue, before publishing the interaction.
//

import UIKit

internal enum InteractionEventCache {

    private struct DebouncedInteractionEnvelope {
        let payload: InteractionPayload
        let textLengthForDedupe: Int?
        let debounceKey: String
    }

    private static let lastDeliveredLock = NSLock()
    private static var lastDeliveredTextLengthByDebounceKey: [String: Int] = [:]

    private static let debouncer = EventDebounce<DebouncedInteractionEnvelope>(
        delay: AutoCaptureConstants.interactionDebounceInterval,
        deliveryQueue: .main
    ) { envelope in
        guard Userpilot.isInitialized else { return }
        // swiftlint:disable:next multiple_closures_with_trailing_closure superfluous_disable_command
        if let length = envelope.textLengthForDedupe {
            lastDeliveredLock.lock()
            lastDeliveredTextLengthByDebounceKey[envelope.debounceKey] = length
            lastDeliveredLock.unlock()
        }
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(envelope.payload)
    }

    /// Schedules sending the interaction after `interactionDebounceInterval` of quiet time for this view.
    ///
    /// - Parameter textLengthForDedupe: For text field / text view, pass current `text.count` so a new
    ///   notification with the same length as the last delivered event is ignored. Omit for sliders.
    static func sendDebouncedInteraction(
        _ payload: InteractionPayload,
        for view: UIView,
        textLengthForDedupe: Int? = nil
    ) {
        guard Userpilot.isInitialized else { return }
        let key = debounceKey(for: view)

        if let length = textLengthForDedupe {
            lastDeliveredLock.lock()
            let last = lastDeliveredTextLengthByDebounceKey[key]
            lastDeliveredLock.unlock()
            guard last != length else { return }
        }

        let envelope = DebouncedInteractionEnvelope(
            payload: payload,
            textLengthForDedupe: textLengthForDedupe,
            debounceKey: key
        )
        debouncer.schedule(key: key, value: envelope)
    }

    static func flushAll() {
        debouncer.cancelAll()
        lastDeliveredLock.lock()
        lastDeliveredTextLengthByDebounceKey.removeAll()
        lastDeliveredLock.unlock()
    }

    private static func debounceKey(for view: UIView) -> String {
        "interaction_debounce_\(ObjectIdentifier(view))"
    }
}
