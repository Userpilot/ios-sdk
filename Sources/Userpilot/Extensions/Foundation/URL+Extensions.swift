//
//  URL+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 30/12/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
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

    /// Accepts only this account's full token scheme, SDK host, and two-part preview path.
    func previewExperienceID(token: String) -> String? {
        // Keep the staging prefix: STG-NX-123 matches userpilot-stg-nx-123, not userpilot-nx-123.
        guard scheme?.lowercased() == "userpilot-\(token)".lowercased(), host == "sdk" else {
            return nil
        }

        let pathTokens = path.split(separator: "/")
        guard pathTokens.count == 2, pathTokens[0] == "experience_preview" else { return nil }
        return String(pathTokens[1])
    }
}
