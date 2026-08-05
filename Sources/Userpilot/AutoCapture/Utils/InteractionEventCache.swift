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

    /// Holds the payload, dedup metadata, and a weak reference to the source view so the
    /// owning `Userpilot` instance can be re-resolved at delivery time. Keeping the view
    /// reference weak prevents the cache from extending the source's lifetime.
    private final class DebouncedInteractionEnvelope {
        let payload: InteractionPayload
        let textLengthForDedupe: Int?
        let debounceKey: String
        weak var source: UIView?

        init(
            payload: InteractionPayload,
            textLengthForDedupe: Int?,
            debounceKey: String,
            source: UIView?
        ) {
            self.payload = payload
            self.textLengthForDedupe = textLengthForDedupe
            self.debounceKey = debounceKey
            self.source = source
        }
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
        // Re-resolve the owning instance at delivery time so it always reflects the
        // current Registry state. If the source view has been deallocated, fall back
        // to the registered default.
        InstanceResolver.shared.handleInteractionEvent(envelope.payload, source: envelope.source)
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
            debounceKey: key,
            source: view
        )
        debouncer.schedule(key: key, value: envelope)
    }

    static func flushAll() {
        debouncer.cancelAll()
        lastDeliveredLock.lock()
        lastDeliveredTextLengthByDebounceKey.removeAll()
        lastDeliveredLock.unlock()
    }

    /// Publishes any debounced interaction that is still waiting for its quiet period.
    ///
    /// Called before a manual `screen` event so a text change the user made on the previous screen is
    /// published first, instead of arriving after the screen event and being attributed to the screen
    /// the user navigated to. The debouncer is process-wide, so this also delivers pending
    /// interactions belonging to other instances — each one still resolves its own owner at delivery
    /// time, they are simply published a little earlier than their debounce would have.
    static func flushPendingInteractions() {
        debouncer.flushPending()
    }

    private static func debounceKey(for view: UIView) -> String {
        "interaction_debounce_\(ObjectIdentifier(view))"
    }
}
