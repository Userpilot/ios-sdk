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
/// The weak source view records the delivered text length, so a released field records nothing.
internal final class PendingInteraction {
    let payload: InteractionPayload
    let textLengthForDedupe: Int?
    weak var owner: Userpilot?
    weak var view: UIView?

    init(
        payload: InteractionPayload,
        textLengthForDedupe: Int?,
        owner: Userpilot,
        view: UIView
    ) {
        self.payload = payload
        self.textLengthForDedupe = textLengthForDedupe
        self.owner = owner
        self.view = view
    }
}
