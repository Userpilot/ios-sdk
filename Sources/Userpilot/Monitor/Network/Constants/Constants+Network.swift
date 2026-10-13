//
//  Constants+Network.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  First-party network reachability configuration.
//

import Foundation

extension Constants {

    /// Network reachability configuration.
    enum Network {
        /// First-party host used for active reachability validation.
        /// Never probe public hosts (Google/Apple/Cloudflare) from customer apps.
        static let reachabilityHost = "find.userpilot.io"
    }
}
