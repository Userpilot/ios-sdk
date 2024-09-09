//
//  Endpoint.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// Endpoint to configure and setup restfull APIs
//

import Foundation

protocol Endpoint {
    func url(config: UserPilot.Config, storage: DataStoring) -> URL?
}

// MARK: - Settings end points
enum SettingsEndpoint: Endpoint {
    case settings

    func url(config: UserPilot.Config, storage: DataStoring) -> URL? {
        guard
            var components = URLComponents(url: NetworkClient.defaultSettingsHost, resolvingAgainstBaseURL: false)
        else { return nil }

        switch self {
        case .settings:
            components.path = "/bundle/accounts/\(config.token)/mobile/settings"
        }

        return components.url
    }
}
