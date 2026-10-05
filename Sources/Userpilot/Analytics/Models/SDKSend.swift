//
//  SDKSend.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Holds an in-memory SDK queue entry with its admission check and completion callback.
//

import Foundation

/// An in-memory SDK queue entry; transport callbacks are never part of the event payload or storage.
internal struct SDKSend {
    let event: SDKEvent
    let shouldSend: () -> Bool
    let completion: SocketCompletion?
}
