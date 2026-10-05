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

/// Defaults retain the original fire-and-forget contract for legacy test doubles.
/// The production manager implements the completion overloads directly.
extension SocketManaging {
    func publish(
        _ eventName: String, payload: Payload, userID: String? = nil,
        shouldSend: @escaping () -> Bool = { true }, completion: SocketCompletion? = nil
    ) {
        guard shouldSend() else { return }
        publish(eventName, payload: payload)
    }

    func close(completion: @escaping () -> Void) {
        close()
        performOn(.main, closure: completion)
    }
}
