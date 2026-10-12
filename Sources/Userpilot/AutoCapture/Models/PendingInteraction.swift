//
//  PendingInteraction.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Keeps a pending capture payload bound to its original owner without retaining that instance.
//

import UIKit

/// Holds the captured payload and weak original owner. Deferred delivery never redirects
/// an interaction when its source disappears or another instance becomes the default.
internal final class PendingInteraction {
    let payload: InteractionPayload
    let textLengthForDedupe: Int?
    let debounceKey: String
    weak var owner: Userpilot?

    init(
        payload: InteractionPayload,
        textLengthForDedupe: Int?,
        debounceKey: String,
        owner: Userpilot
    ) {
        self.payload = payload
        self.textLengthForDedupe = textLengthForDedupe
        self.debounceKey = debounceKey
        self.owner = owner.canonicalInstance
    }
}
