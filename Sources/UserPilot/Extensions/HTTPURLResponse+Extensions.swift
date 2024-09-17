//
//  HTTPURLResponse+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `HTTPURLResponse+Data` contains an extension with helper methods for the `HTTPURLResponse` class.
//  This extension provides additional functionality to easily check if the HTTP status code indicates
// a successful response.
//
//  Extensions include:
//  - `isSuccessStatusCode`: A computed property that returns `true` if the status code is in the 2xx range,
// indicating a successful response.
//

import Foundation

extension HTTPURLResponse {

    var isSuccessStatusCode: Bool {
        (200...299).contains(statusCode)
    }

}
