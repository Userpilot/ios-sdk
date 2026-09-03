//
//  Environment.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/04/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  A utility struct that handles environment-specific configuration settings for the Userpilot SDK.
//  Determines the appropriate socket URL, client token, and public content API host based on the
//  environment (development, staging, production). Automatically adjusts configuration depending on
//  build environment to ensure correct SDK behavior.
//

import Foundation

internal struct Environment {

    // Environment configuration
    internal static let environmentType: EnvironmentType = .PRODUCTION
    private static let socketUrl = "<#SOCKET_URL#>"
    private static let clientToken = "<#TOKEN#>"
    private static let experienceContentUrlProduction =
        "https://appex.userpilot.io/api/v1/public/content"
    private static let experienceContentUrlDevelopment =
        "https://appex-dev.userpilot.io/api/v1/public/content"

    /**
     Enum representing the possible environment types.
     */
    enum EnvironmentType: String {
        case DEVELOPMENT
        case STAGING
        case PRODUCTION
    }

    /**
     Returns the appropriate socket URL based on the current environment type.
     
     - Parameters:
       - storage: An instance of the `Storage` class used to fetch the socket URL
        for non-DEVELOPMENT/STAGING environments.
     
     - Returns: The socket URL as a `String`.
     */
    static func getSocketURL(storage: DataStoring) -> String {
        switch environmentType {
        case .DEVELOPMENT, .STAGING:
            return socketUrl
        case .PRODUCTION:
            return storage.socketURL
        }
    }

    /**
     Returns the appropriate client token based on the current environment type.
     
     - Parameters:
       - config: An instance of `UserpilotConfig` used to fetch the client token for non-DEVELOPMENT environments.
     
     - Returns: The client token as a `String`.
     */
    static func getClientToken(config: Userpilot.Config) -> String {
        switch environmentType {
        case .DEVELOPMENT:
            return clientToken
        case .STAGING, .PRODUCTION:
            return config.token
        }
    }

    /**
     Returns the public content API base URL for preview experiences.

     - DEVELOPMENT uses the QA host.
     - STAGING and PRODUCTION use the live host.

     - Returns: The experience content base URL as a `String`.
     */
    static func getExperienceContentUrl() -> String {
        switch environmentType {
        case .DEVELOPMENT:
            return experienceContentUrlDevelopment
        case .STAGING, .PRODUCTION:
            return experienceContentUrlProduction
        }
    }
}
