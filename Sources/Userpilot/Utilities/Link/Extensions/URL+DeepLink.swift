//
//  URL+DeepLink.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Parses SDK preview links without changing query values or routing UI work.
//

import Foundation

extension URL {
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
