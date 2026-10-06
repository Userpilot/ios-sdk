//
//  PendingInteraction.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Keeps a pending capture payload without retaining its source view.
//

import UIKit

/// Holds the payload, dedup metadata, and a weak reference to the source view so the
/// owning `Userpilot` instance can be re-resolved at delivery time. Keeping the view
/// reference weak prevents the cache from extending the source's lifetime.
internal final class PendingInteraction {
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
