//
//  HTTPURLResponse+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `HTTPURLResponse+Extension` contains an extension with helper methods for the `HTTPURLResponse` class.
//  This extension provides additional functionality to easily check if the HTTP status code indicates
// a successful response.
//

import Foundation

internal extension HTTPURLResponse {

    var isSuccessStatusCode: Bool {
        (200...299).contains(statusCode)
    }

}
