//
//  Socket+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 16/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Extension property for Phoenix message to verify it's a valid message or not.
//

import Foundation

internal extension Message {

    var isInvalidMessage: Bool {
        self.payload.isEmpty || self.event == "phx_close" || self.topic == "phoenix"
    }

    var resolvedEvent: String? {
        return (payload["request_type"] as? String)
    }
}
