//
//  InteractionEventCache.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Captures payloads and remembers delivered text lengths. Each owning coordinator debounces
//  its own text and slider interactions; this helper owns no timers or process-wide pending work.
//
//  For text inputs, if `text_length` matches the last delivered event for that field, the new notification
//  is ignored (e.g. spurious `textDidChange` when tapping another control). Last length is updated when the
//  debounced delivery runs on the main queue, before publishing the interaction. Delivered lengths live on
//  the field itself, so they are released with it and never carry over to a field reusing its address.
//

import UIKit

internal enum InteractionEventCache {

    /// Schedules sending the interaction after `interactionDebounceInterval` of quiet time for this view.
    /// Main thread only, like the UIKit callers that capture the payload.
    ///
    /// - Parameter textLengthForDedupe: For text field / text view, pass current `text.count` so a new
    ///   notification with the same length as the last delivered event is ignored. Omit for sliders.
    static func sendDebouncedInteraction(
        _ payload: InteractionPayload,
        for view: UIView,
        owner: Userpilot,
        textLengthForDedupe: Int? = nil
    ) {
        guard UserpilotRuntime.shared.instanceRegistry.isRegistered(owner) else { return }
        let key = debounceKey(for: view, owner: owner.canonicalInstance)

        if let length = textLengthForDedupe,
           view.userpilotDeliveredTextLengths.byOwner[ObjectIdentifier(owner.canonicalInstance)] == length {
            return
        }

        let envelope = PendingInteraction(
            payload: payload,
            textLengthForDedupe: textLengthForDedupe,
            owner: owner,
            view: view
        )
        owner.autoCaptureCoordinator.scheduleInteraction(key: key) { deliver(envelope) }
    }

    /// Only delivered lengths participate in deduplication; scheduling alone must not mark a value seen.
    private static func deliver(_ envelope: PendingInteraction) {
        guard let owner = envelope.owner,
              UserpilotRuntime.shared.instanceRegistry.isRegistered(owner),
              !owner.autoCaptureCoordinator.isStopped else { return }
        if let length = envelope.textLengthForDedupe {
            envelope.view?.userpilotDeliveredTextLengths.byOwner[ObjectIdentifier(owner)] = length
        }
        owner.autoCaptureCoordinator.handleInteractionEvent(envelope.payload)
    }

    private static func debounceKey(for view: UIView, owner: Userpilot) -> String {
        "interaction_debounce_\(ObjectIdentifier(owner))_\(ObjectIdentifier(view))"
    }
}

/// The last text length a field delivered, per owner.
private final class DeliveredTextLengths {
    var byOwner: [ObjectIdentifier: Int] = [:]
}

private var deliveredTextLengthsKey: UInt8 = 0

private extension UIView {
    var userpilotDeliveredTextLengths: DeliveredTextLengths {
        if let lengths = objc_getAssociatedObject(self, &deliveredTextLengthsKey) as? DeliveredTextLengths {
            return lengths
        }
        let lengths = DeliveredTextLengths()
        objc_setAssociatedObject(self, &deliveredTextLengthsKey, lengths, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return lengths
    }
}
