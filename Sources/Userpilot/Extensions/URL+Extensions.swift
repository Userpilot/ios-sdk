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
    var isWebLink: Bool {
        return scheme?.lowercased() == "http" || scheme?.lowercased() == "https"
    }

    var queryItems: [URLQueryItem] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
    }

    func queryValue(for name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name.lowercased() == name }?
            .value
    }
}
