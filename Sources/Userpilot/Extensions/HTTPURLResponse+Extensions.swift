//
//  HTTPURLResponse+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  `HTTPURLResponse+Extension` contains an extension with helper methods for the `HTTPURLResponse` class.
//  This extension provides additional functionality to easily check if the HTTP status code indicates
//  a successful response.
//

import Foundation

internal extension HTTPURLResponse {

    var isSuccessStatusCode: Bool {
        (200...299).contains(statusCode)
    }

}
