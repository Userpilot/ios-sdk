//
//  SdkSettings.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// SdkSettings Determine client status using accout token
//

import Foundation

// The response model for the Userpilot settings endpoint,
// http://run.userpilot.com/bundle/accounts/{token}/mobile/settings.
struct SdkSettings: Decodable {

    struct Services: Decodable {
        let customerApi: String
    }

    let services: Services
}
