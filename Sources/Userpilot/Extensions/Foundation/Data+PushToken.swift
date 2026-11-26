//
//  Data+PushToken.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  APNs device-token encoding for token updates.
//

import Foundation

extension Data {

    /// Preserves leading zeroes while encoding every APNs byte as lowercase hexadecimal.
    var pushTokenString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
