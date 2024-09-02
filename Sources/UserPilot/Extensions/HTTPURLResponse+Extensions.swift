//
//  HTTPURLResponse+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// HTTPURLResponse+Data contains extensions helper methods
//

import Foundation

extension HTTPURLResponse {

    var isSuccessStatusCode: Bool {
        (200...299).contains(statusCode)
    }

}
