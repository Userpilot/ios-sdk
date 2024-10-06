//
//  SDKSettingsDetector.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 17/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `SDKSettingsDetector` responsible for fetching SDK settings.
//
//  It allows events to be mutated or updated to add additional context or information as needed by conforming classes.
//

import Foundation

/**
 * `SDKSettingsDetectoring` is a protocol that defines the interface for classes
 * responsible for fetching SDK settings.
 */
internal protocol SDKSettingsDetectoring: AnyObject {
    /**
     * Fetches SDK settings and invokes the provided callback upon completion.
     *
     * - Parameter callback: A closure to be executed after the settings have been fetched.
     */
    func fetchSettings(callback: @escaping () -> Void)
}

/**
 * `SDKSettingsDetector` is a class that implements `SDKSettingsDetectoring` protocol.
 * It fetches SDK settings from a remote server and updates the storage with the obtained data.
 */
internal class SDKSettingsDetector {

    // MARK: - Properties

    /// Base URL for the SDK settings API.
    let baseURL = "https://find.userpilot.io/v1/lookups/"

    /// A configuration instance holding SDK-related configuration details.
    private let config: UserPilot.Config

    /// Logger instance for logging information and errors.
    private let logger: Logging

    /// Storage used to store user-related data.
    private var storage: DataStoring

    // MARK: - Initialization

    /**
     * Initializes the `SDKSettingsDetector` with dependencies from the provided dependency injection container.
     *
     * - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = container.resolve(UserPilot.Config.self).logger
    }
}

// MARK: - SDKSettingsDetectoring

extension SDKSettingsDetector: SDKSettingsDetectoring {

    /**
     * Fetches SDK settings from the remote server and updates the storage with the obtained data.
     *
     * - Parameter callback: A closure to be executed after the settings have been fetched.
     */
    func fetchSettings(callback: @escaping () -> Void) {
        let urlString = baseURL + config.token
        guard let url = URL(string: urlString) else {
            self.logger.error("Invalid URL: %{public}@", urlString)
            callback()
            return
        }

        let request = URLRequest(url: url)

        // Perform the network request asynchronously on a background thread
        DispatchQueue.global(qos: .background).async {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    self.logger.error("Request failed: %{public}@", error.localizedDescription)
                    callback()
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.isSuccessStatusCode else {
                    if let httpResponse = response as? HTTPURLResponse {
                        self.logger.error("Request failed with code: %{public}@", httpResponse.statusCode)
                    }
                    callback()
                    return
                }

                // swiftlint:disable:next non_optional_string_data_conversion
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    self.logger.info("RSDK Settings response: %{public}@", responseBody)
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let endpoint = json["endpoint"] as? String {
                            self.storage.socketURL = endpoint
                        }
                    } catch {
                        // Log an error if JSON parsing fails
                        self.logger.error("Failed to parse JSON: %{public}@", error.localizedDescription)
                    }
                }
                callback()
            }
            task.resume()
        }
    }
}
