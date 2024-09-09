//
//  SettingsVerifing.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  A utility class for verifying settings and obtaining the customer base URL.
//  Conforms to the SettingsVerifing protocol to perform settings verification and update
//  the configuration and data storage accordingly.
//

import Foundation

/// A protocol defining the interface for verifying settings.
///
/// Conforming types are expected to implement the `verifySettings` method, which performs
/// verification of settings and invokes the completion handler upon completion.
protocol SettingsVerifing: AnyObject {
    func verifySettings(completion: @escaping () -> Void)
}

/// A class responsible for verifying settings and updating configuration and data storage.
///
/// Conforms to the `SettingsVerifing` protocol and uses dependency injection to access
/// configuration, networking, and data storage services.
class SettingsVerifier {

    // MARK: - Properties

    /// The configuration object used for logging and accessing configuration settings.
    let config: UserPilot.Config

    /// The networking service used for making API requests.
    let networking: Networking

    /// The data storage service used for persisting data such as the socket URL.
    let dataStoring: DataStoring

    // MARK: - Initialization

    /**
     Initializes the `SettingsVerifier` with dependencies from the provided dependency injection container.
     
     - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
        self.networking = container.resolve(Networking.self)
        self.dataStoring = container.resolve(DataStoring.self)
    }

}

// MARK: - SettingsVerifing

extension SettingsVerifier: SettingsVerifing {

    /// Verifies settings by making a network request to fetch the settings from an endpoint.
    /// Updates the configuration and data storage based on the fetched settings.
    ///
    /// - Parameter completion: A closure to be executed upon completion of the settings verification.
    func verifySettings(completion: @escaping () -> Void) {
        networking.get(from: SettingsEndpoint.settings) { [weak self] (result: Result<SdkSettings, Error>) in
            switch result {
            case .success(let sdkSettings):
                // Log the obtained customer API URL
                self?.config.logger.info("Customer API URL: %{private}@ obtained", sdkSettings.services.customerApi)

                // Update the data storing service with the customer API URL
                self?.dataStoring.socketURL = sdkSettings.services.customerApi

                // Execute the completion handler
                completion()

            case .failure(let error):
                // Log the error encountered while fetching settings
                self?.config.logger.info("Settings API error: %{public}@", error.localizedDescription)
            }
        }
    }
}
