//
//  Message+Extension.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 16/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  Extension property for Phoenix message to verify it's a valid message or not.
//

import Foundation
import SwiftPhoenixClient

extension Message {

    var isInvalidMessage: Bool {
        self.payload.isEmpty || self.event == "phx_close" || self.topic == "phoenix"
    }

}
