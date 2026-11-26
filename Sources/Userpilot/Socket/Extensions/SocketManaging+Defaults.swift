//
//  SocketManaging+Defaults.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Provides compatibility defaults for socket admission, completion and close operations.
//

import Foundation

/// Convenience entry points forward every argument to the protocol requirement so dynamic dispatch
/// preserves the concrete manager's cancellation and per-request completion handling.
extension SocketManaging {
    func publish(
        _ eventName: String, payload: Payload,
        shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    ) {
        publish(eventName, payload: payload, userID: nil, shouldSend: shouldSend, completion: completion)
    }

    func close(completion: @escaping () -> Void) {
        close()
        performOn(.main, closure: completion)
    }
}
