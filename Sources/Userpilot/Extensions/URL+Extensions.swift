//
//  URL+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 30/12/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `URL+Extension` contains extensions with helper methods for the `URL` class.
//

import Foundation

internal extension URL {
    var isHttpOrHttps: Bool {
        return scheme == "http" || scheme == "https"
    }
}
