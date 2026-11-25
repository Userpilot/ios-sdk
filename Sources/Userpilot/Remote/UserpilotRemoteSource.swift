//
//  UserpilotRemoteSource.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/09/2024.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Fetches cached SDK settings and preview content, and uploads Builder captures,
//  with the existing URLSession transport.
//

import Foundation

// MARK: - Protocol

internal protocol UserpilotRemoteSourcing: AnyObject {
    /// Uses fresh cached settings immediately; network completions keep URLSession delivery.
    func fetchSettings(completion: @escaping (Result<Void, RemoteSourceError>) -> Void)

    /// Fetches preview content without caching or changing the callback queue.
    func fetchPreviewExperience(
        params: PreviewExperienceQueryParams,
        completion: @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void
    )

    /// Posts one prepared capture to the capture upload URL with its Bearer token. One attempt of at most
    /// `requestTimeout` seconds in total; the caller owns retries. Completion runs once on URLSession's queue.
    @discardableResult
    func uploadCapture(
        _ upload: CaptureUpload,
        token: CaptureToken,
        url: URL,
        completion: @escaping (Result<Void, CaptureUploadError>) -> Void
    ) -> CaptureUploadCancellable
}

/// An in-flight capture upload. Cancelling reports `.cancelled` once through the upload's completion.
internal protocol CaptureUploadCancellable: AnyObject {
    func cancel()
}

extension URLSessionTask: CaptureUploadCancellable {}

/// `UserpilotRemoteSource` is a class that handles all remote API interactions.
/// It fetches SDK settings and preview experiences, and uploads Builder captures.
internal final class UserpilotRemoteSource {

    // MARK: - Dependencies

    private let config: Userpilot.Config
    private let logger: Logging
    private let storage: DataStoring
    private let session: URLSession
    /// Capture uploads only: `timeoutIntervalForResource` bounds a whole attempt, body upload included,
    /// which `URLRequest.timeoutInterval` (an idle timeout) cannot.
    let uploadSession: URLSession

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
        self.uploadSession = Self.makeUploadSession(configuration: .ephemeral)
    }

    // Custom (test) initializer
    #if DEBUG
        init(container: DIContainer, session: URLSession) {
            self.config = container.resolve(Userpilot.Config.self)
            self.storage = container.resolve(DataStoring.self)
            self.logger = config.logger
            self.session = session
            // Keeps the test session's protocol classes, so stubs see capture uploads too.
            self.uploadSession = Self.makeUploadSession(configuration: session.configuration)
        }
    #endif

    deinit {
        uploadSession.finishTasksAndInvalidate()
    }

    /// Ephemeral and uncached: nothing about an upload outlives its request.
    private static func makeUploadSession(configuration: URLSessionConfiguration) -> URLSession {
        let configuration = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.timeoutIntervalForResource = Constants.BuilderCapture.Upload.requestTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    // MARK: - Private Helper Methods

    /// Checks if cached SDK configuration is still valid.
    private func shouldUseCachedConfiguration() -> Bool {
        guard let configurationDate = storage.configurationDate,
            storage.socketURL.isNotEmpty
        else {
            return false
        }

        let elapsedTime = Date().timeIntervalSince(configurationDate)
        return elapsedTime < Constants.RemoteSource.configurationDuration
    }

    /// Builds the remote settings URL using the SDK token.
    private func buildSettingsUrl() -> String {
        return Constants.RemoteSource.settingsBaseURL + config.token
    }

    /// Executes a network request and returns Result with success or failure.
    private func executeRequest(
        url: String,
        completion: @escaping (Result<Data, RemoteSourceError>) -> Void
    ) {
        guard let requestUrl = URL(string: url) else {
            logger.error("❌ Invalid URL")
            completion(.failure(.invalidURL))
            return
        }

        let task = session.dataTask(with: URLRequest(url: requestUrl)) { [weak self] data, response, error in
            guard let self else {
                completion(.failure(.networkError("Request cancelled")))
                return
            }

            completion(self.handleResponse(data: data, response: response, error: error))
        }
        task.resume()
    }

    /// Maps the transport response once, before endpoint-specific decoding and cache writes.
    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> Result<Data, RemoteSourceError> {
        if let error {
            logger.error("🌐 Network request failed: %{public}@", error.localizedDescription)
            return .failure(.networkError(error.localizedDescription))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type")
            return .failure(.invalidResponse)
        }

        guard httpResponse.isSuccessStatusCode else {
            logger.error("❌ Request failed with code: %{public}@", String(httpResponse.statusCode))
            return .failure(.fromStatusCode(httpResponse.statusCode))
        }

        guard let data else {
            logger.error("📭 Request failed: Empty response body")
            return .failure(.emptyResponse)
        }

        logger.info("✅ Request successful: %{public}@", String(httpResponse.statusCode))
        return .success(data)
    }

    /// Parses SDK settings response and updates socket URL storage. Returns Result.
    private func handleSettingsResponse(_ data: Data) -> Result<Void, RemoteSourceError> {
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.info("⚙️ SDK settings response: %{public}@", responseBody)
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard
                let endpoint = json?["endpoint"] as? String,
                let baseUrl = endpoint.baseURL()
            else {
                logger.error("🔍 Failed to extract endpoint from response")
                return .failure(.decodingError("Failed to extract endpoint from response"))
            }

            storage.configurationDate = Date()
            storage.socketURL = baseUrl + Constants.RemoteSource.socketPath
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
            let previewExperience = try PreviewExperience.decode(from: data)
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

            if case .failure(let error) = result {
                self.logger.error(
                    "❌ Failed to fetch settings: %{public}@", error.localizedDescription)
            }
            completion(result.flatMap(self.handleSettingsResponse))
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
        let url = params.requestURL
        executeRequest(url: url) { [weak self] result in
            guard let self else {
                completion(.failure(.networkError("Request cancelled")))
                return
            }

            if case .failure(let error) = result {
                self.logger.error(
                    "❌ Failed to fetch preview experience: %{public}@", error.localizedDescription)
            }
            completion(result.flatMap(self.handlePreviewExperienceResponse))
        }
    }

    /**
     * Uploads one Builder capture to `url`, exactly as given.
     *
     * The body has three parts: the `capture_id` text, the `screenshot` PNG and the `capture.json` `document`.
     * The token travels only in the `Authorization` header. Logs carry the outcome category, HTTP status and
     * the backend's `details` code, never the token, URL, headers, body or raw transport error.
     *
     * - Parameters:
     *   - upload: The prepared capture id, PNG and document bytes
     *   - token: The Builder session credential
     *   - url: The environment's capture upload URL
     *   - completion: Closure invoked once with success for any 2xx, or a safe `CaptureUploadError`
     * - Returns: The running request
     */
    @discardableResult
    func uploadCapture(
        _ upload: CaptureUpload,
        token: CaptureToken,
        url: URL,
        completion: @escaping (Result<Void, CaptureUploadError>) -> Void
    ) -> CaptureUploadCancellable {
        typealias Upload = Constants.BuilderCapture.Upload
        var body = MultipartFormBody()
        body.append(field: Upload.captureIDPart, value: upload.captureID)
        body.append(file: Upload.screenshotPart, fileName: Upload.screenshotFileName,
                    contentType: Upload.screenshotContentType, data: upload.screenshot)
        body.append(file: Upload.documentPart, fileName: Upload.documentFileName,
                    contentType: Upload.documentContentType, data: upload.document)

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Upload.requestTimeout
        )
        request.httpMethod = "POST"
        request.setValue(token.bearerHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.encoded()

        let task = uploadSession.dataTask(with: request) { [weak self] data, response, error in
            let result = CaptureUploadError.result(data: data, response: response, error: error)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            switch result {
            case .success:
                self?.logger.info("📸 Capture uploaded: saved (status %{public}@)", String(statusCode ?? 0))
            case .failure(.cancelled):
                // The SDK cancelled the request itself (stop, replacement or background expiry); nothing to log.
                break
            case let .failure(failure):
                let details = CaptureUploadError.details(in: data)
                self?.logger.error("📸 Capture upload failed: %{public}@",
                                   failure.logDescription(statusCode: statusCode, details: details))
            }
            completion(result)
        }
        task.resume()
        return task
    }
}
