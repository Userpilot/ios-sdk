//
//  SDKSettingsDetector.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 17/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
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
    /// Fetches SDK settings and invokes the provided callback upon completion.
    func fetchSettings(callback: @escaping () -> Void)
}

/**
 * `SDKSettingsDetector` is a class that implements `SDKSettingsDetectoring` protocol.
 * It fetches SDK settings from a remote server and updates the storage with the obtained data.
 */
internal class SDKSettingsDetector {

    // MARK: - Properties

    /// Base URL for the SDK settings API.
    private let baseURL = "https://find.userpilot.io/v1/lookups/"

    /// A configuration instance holding SDK-related configuration details.
    private let config: Userpilot.Config

    /// Logger instance for logging information and errors.
    private let logger: Logging

    /// Storage used to store user-related data.
    private let storage: DataStoring

    /// URLSession to request API
    private let session: URLSession

    // MARK: - Initialization

    /**
     * Initializes the `SDKSettingsDetector` with dependencies from the provided dependency injection container.
     *
     * - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = config.logger
        self.session = URLSession.shared
    }

    // Custom (test) initializer
    #if DEBUG
    init(container: DIContainer, session: URLSession) {
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.logger = config.logger
        self.session = session
    }
    #endif

}

// MARK: - SDKSettingsDetectoring

extension SDKSettingsDetector: SDKSettingsDetectoring {

    /**
     * Fetches SDK settings from the remote server and updates the storage with the obtained data.
     *
     * - Parameter callback: A closure to be executed after the settings have been fetched.
     */
    func fetchSettings(callback: @escaping () -> Void) {
        if let configurationDate = storage.configurationDate, storage.socketURL.isNotEmpty {
            let difference = Date().timeIntervalSince(configurationDate)
            if difference < GeneralConstants.CONFIGURATION_DURATION {
                callback()
                return
            }
        }

        let urlString = baseURL + config.token
        guard let url = URL(string: urlString) else {
            self.logger.error("Invalid URL: %{public}@", urlString)
            callback()
            return
        }
        let request = getURLRequest(for: url)
        performOn(.highPriority) { [weak self] in
            let task = self?.session.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else {
                    callback()
                    return
                }

                if let error {
                    self.logger.error("Request failed: %{public}@", error.localizedDescription)
                    callback()
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.isSuccessStatusCode else {
                    if let httpResponse = response as? HTTPURLResponse {
                        self.logger.error("Request failed with code: %{public}@", String(httpResponse.statusCode))
                    }
                    callback()
                    return
                }

                if let data, let responseBody = String(data: data, encoding: .utf8) {
                    self.logger.info("SDK Settings response: %{public}@", responseBody)
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let endpoint = json["endpoint"] as? String, let url = endpoint.baseURL() {
                            self.storage.configurationDate = Date()
                            self.storage.socketURL = url + GeneralConstants.PATH_NAME
                        }
                    } catch {
                        self.logger.error("Failed to parse JSON: %{public}@", error.localizedDescription)
                    }
                }
                callback()
            }
            task?.resume()
        }
    }

    /// Prepare URL request
    private func getURLRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(getUserAgent(), forHTTPHeaderField: "User-Agent")
        return request
    }
}
