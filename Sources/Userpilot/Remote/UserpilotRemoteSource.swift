//
//  UserpilotRemoteSource.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 17/09/2024.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `UserpilotRemoteSource` responsible for fetching SDK settings.
//
//  It allows events to be mutated or updated to add additional context or information as needed by conforming classes.
//

import Foundation

// MARK: - Protocol

internal protocol UserpilotRemoteSourcing: AnyObject {
    /// Fetches SDK settings and invokes the provided callback with Result type.
    func fetchSettings(completion: @escaping (Result<Void, RemoteSourceError>) -> Void)

    /// Fetches preview experience from the public content API using Result type.
    func fetchPreviewExperience(
        params: PreviewExperienceQueryParams,
        completion: @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void
    )
}

/// `UserpilotRemoteSource` is a class that handles all remote API interactions.
/// It fetches SDK settings and preview experiences from remote servers.
internal class UserpilotRemoteSource {

    // MARK: - Properties

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
     * Initializes the `UserpilotRemoteSource` with dependencies from the provided dependency injection container.
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

    // MARK: - Private Helper Methods

    /// Checks if cached SDK configuration is still valid.
    private func shouldUseCachedConfiguration() -> Bool {
        guard let configurationDate = storage.configurationDate,
            storage.socketURL.isNotEmpty
        else {
            return false
        }

        let elapsedTime = Date().timeIntervalSince(configurationDate)
        return elapsedTime < RemoteSource.configurationDuration
    }

    // Returns appropriate error message based on HTTP status code.
    // swiftlint:disable:next cyclomatic_complexity
    private func getErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Bad request: The content request is invalid"
        case 401:
            return "Unauthorized: Invalid or missing authentication"
        case 403:
            return "Forbidden: Access to this content is denied"
        case 404:
            return "Not found: The requested content could not be found"
        case 408:
            return "Request timeout: The server took too long to respond"
        case 429:
            return "Too many requests: Please try again later"
        case 500:
            return "Server error: The server encountered an internal error"
        case 502:
            return "Bad gateway: The server received an invalid response"
        case 503:
            return "Service unavailable: The server is temporarily unavailable"
        case 504:
            return "Gateway timeout: The server did not respond in time"
        default:
            return "Request failed with status code: \(statusCode)"
        }
    }

    /// Builds the remote settings URL using the SDK token.
    private func buildSettingsUrl() -> String {
        return RemoteSource.settingsBaseURL + config.token
    }

    /// Builds the URL for fetching preview experience content.
    private func buildPreviewExperienceUrl(params: PreviewExperienceQueryParams) -> String {
        var components = URLComponents(string: params.baseUrl)
        components?.queryItems = [
            URLQueryItem(name: "app_token", value: params.appToken),
            URLQueryItem(name: "content_type", value: params.contentType),
            URLQueryItem(name: "content_id", value: params.contentId)
        ]
        return components?.url?.absoluteString ?? params.baseUrl
    }

    /// Executes a network request and returns Result with success or failure.
    private func executeRequest(
        url: String,
        completion: @escaping (Result<Data, RemoteSourceError>) -> Void
    ) {
        guard let requestUrl = URL(string: url) else {
            logger.error("❌ Invalid URL: %{public}@", url)
            completion(.failure(.invalidURL))
            return
        }

        logger.info("✅ Request URL: %{public}@", url)

        let task = session.dataTask(with: URLRequest(url: requestUrl)) { [weak self] data, response, error in
            guard let self else {
                completion(.failure(.networkError("Request cancelled")))
                return
            }

            if let error {
                self.logger.error("🌐 Network request failed: %{public}@", error.localizedDescription)
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ Invalid response type")
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.isSuccessStatusCode else {
                let errorMessage = self.getErrorMessage(statusCode: httpResponse.statusCode)
                self.logger.error("❌ Request failed with code: %{public}@", String(httpResponse.statusCode))
                completion(
                    .failure(.httpError(statusCode: httpResponse.statusCode, message: errorMessage))
                )
                return
            }

            guard let data else {
                self.logger.error("📭 Request failed: Empty response body")
                completion(.failure(.emptyResponse))
                return
            }

            self.logger.info("✅ Request successful: %{public}@", String(httpResponse.statusCode))
            completion(.success(data))
        }
        task.resume()
    }

    /// Parses SDK settings response and updates socket URL storage. Returns Result.
    private func handleSettingsResponse(_ data: Data) -> Result<Void, RemoteSourceError> {
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.info("⚙️ SDK settings response: %{public}@", responseBody)
        }

        do {
            guard
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                    as? [String: Any],
                let endpoint = json["endpoint"] as? String,
                let baseUrl = endpoint.baseURL()
            else {
                logger.error("🔍 Failed to extract endpoint from response")
                return .failure(.decodingError("Failed to extract endpoint from response"))
            }

            storage.configurationDate = Date()
            storage.socketURL = baseUrl + RemoteSource.socketPath
            logger.info("🔗 Socket URL updated: %{public}@", storage.socketURL)
            return .success(())
        } catch {
            logger.error("💥 Failed to parse settings response: %{public}@", error.localizedDescription)
            return .failure(.decodingError(error.localizedDescription))
        }
    }

    /// Parses preview experience API response and returns result.
    private func handlePreviewExperienceResponse(_ data: Data) -> Result<
        PreviewExperience, RemoteSourceError
    > {
        logger.info("📱 Preview experience response received")

        do {
            let decoder = JSONDecoder()
            let previewExperience = try decoder.decode(PreviewExperience.self, from: data)
            logger.info("✅ Successfully parsed Preview experience")
            return .success(previewExperience)
        } catch {
            logger.error("💥 Failed to process Preview experience: %{public}@", error.localizedDescription)
            return .failure(.decodingError(error.localizedDescription))
        }
    }
}

// MARK: - UserpilotRemoteSourcing

extension UserpilotRemoteSource: UserpilotRemoteSourcing {

    /**
     * Fetches SDK settings from the remote server and updates storage with the socket URL.
     *
     * This method implements caching logic to avoid unnecessary network calls. Settings are
     * refreshed only if the cached configuration is older than the configuration duration.
     *
     * - Parameter completion: Closure invoked with Result containing Void on success or RemoteSourceError on failure
     */
    func fetchSettings(completion: @escaping (Result<Void, RemoteSourceError>) -> Void) {
        if shouldUseCachedConfiguration() {
            logger.info("📋 Using cached SDK settings")
            completion(.success(()))
            return
        }

        let url = buildSettingsUrl()
        executeRequest(url: url) { [weak self] result in
            guard let self else {
                completion(.failure(.networkError("Request cancelled")))
                return
            }

            switch result {
            case .success(let data):
                let result = self.handleSettingsResponse(data)
                completion(result)
            case .failure(let error):
                self.logger.error(
                    "❌ Failed to fetch settings: %{public}@", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    /**
     * Fetches preview experience from the public content API.
     *
     * This method retrieves survey or other content types based on the provided parameters. The
     * response is parsed into a PreviewExperience object using Codable.
     *
     * - Parameters:
     *   - params: Query parameters for the content request
     *   - completion: Closure invoked with Result containing PreviewExperience or RemoteSourceError
     */
    func fetchPreviewExperience(
        params: PreviewExperienceQueryParams,
        completion: @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void
    ) {
        let url = buildPreviewExperienceUrl(params: params)
        executeRequest(url: url) { [weak self] result in
            guard let self else {
                completion(.failure(.networkError("Request cancelled")))
                return
            }

            switch result {
            case .success(let data):
                let result = self.handlePreviewExperienceResponse(data)
                completion(result)
            case .failure(let error):
                self.logger.error(
                    "❌ Failed to fetch preview experience: %{public}@", error.localizedDescription)
                completion(.failure(error))
            }
        }
    }
}
