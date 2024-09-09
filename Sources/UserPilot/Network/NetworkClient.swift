//
//  NetworkClient.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// NetworkClient to handle all app network requests
//

import Foundation

protocol Networking: AnyObject {
    func get<T: Decodable>(
        from endpoint: Endpoint,
        completion: @escaping (_ result: Result<T, Error>) -> Void
    )
    func post<T: Decodable>(
        to endpoint: Endpoint,
        body: Data?,
        requestId: UUID?,
        completion: @escaping (_ result: Result<T, Error>) -> Void
    )
    func post(
        to endpoint: Endpoint,
        body: Data?,
        completion: @escaping (_ result: Result<Void, Error>) -> Void
    )
    func put(
        to endpoint: Endpoint,
        body: Data,
        contentType: String,
        completion: @escaping (_ result: Result<Void, Error>) -> Void
    )
}

class NetworkClient {

    // MARK: - Properties
    private let config: UserPilot.Config
    private let storage: DataStoring

    /// Network session base URL
    let urlSession: URLSession = NetworkClient.defaultURLSession

    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
    }

}

// MARK: - Networking
extension NetworkClient: Networking {

    func get<T: Decodable>(
        from endpoint: Endpoint,
        completion: @escaping (_ result: Result<T, Error>) -> Void
    ) {
        guard let requestURL = endpoint.url(config: config, storage: storage) else {
            completion(.failure(NetworkingError.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        handleRequest(request, requestId: nil, completion: completion)
    }

    func post<T: Decodable>(
        to endpoint: Endpoint,
        body: Data?,
        requestId: UUID?,
        completion: @escaping (_ result: Result<T, Error>) -> Void
    ) {
        guard let requestURL = endpoint.url(config: config, storage: storage) else {
            completion(.failure(NetworkingError.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = body

        handleRequest(request, requestId: requestId, completion: completion)
    }

    func post(
        to endpoint: Endpoint,
        body: Data?,
        completion: @escaping (_ result: Result<Void, Error>) -> Void
    ) {
        guard let requestURL = endpoint.url(config: config, storage: storage) else {
            completion(.failure(NetworkingError.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = body

        handleRequest(request, completion: completion)
    }

    func put(
        to endpoint: Endpoint,
        body: Data,
        contentType: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let requestURL = endpoint.url(config: config, storage: storage) else {
            completion(.failure(NetworkingError.invalidURL))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        handleRequest(request, completion: completion)
    }

}

// MARK: - Core methods, handle all requests
extension NetworkClient {

    // version that decodes the response into the given type T
    private func handleRequest<T: Decodable>(
        _ urlRequest: URLRequest,
        requestId: UUID?,
        completion: @escaping (_ result: Result<T, Error>) -> Void
    ) {
        let dataTask = urlSession.dataTask(with: urlRequest) { [weak self] data, response, error in
            let url = (response?.url ?? urlRequest.url)?.absoluteString ?? "<unknown>"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            // swiftlint:disable:next non_optional_string_data_conversion
            let logData = String(data: error?.data ?? data ?? Data.empty, encoding: .utf8) ?? ""

            self?.config.logger.debug("RESPONSE: %{public}d %{public}@\n%{private}@", statusCode, url, logData)

            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, !httpResponse.isSuccessStatusCode {
                completion(.failure(NetworkingError.nonSuccessfulStatusCode(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkingError.noData))
                return
            }

            do {
                let responseObject = try Self.decoder.decode(T.self, from: data)
                completion(.success(responseObject))
            } catch {
                completion(.failure(error))
            }
        }

        if let method = urlRequest.httpMethod, let url = urlRequest.url?.absoluteString {
            // swiftlint:disable:next non_optional_string_data_conversion
            let data = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? ""
            config.logger.debug("REQUEST: %{public}@ %{public}@\n%{private}@", method, url, data)
        }

        dataTask.resume()
    }

    // version that does not decode any response object, assumes empty or discards
    private func handleRequest(
        _ urlRequest: URLRequest,
        completion: @escaping (_ result: Result<Void, Error>) -> Void
    ) {
        let dataTask = urlSession.dataTask(with: urlRequest) { [weak self] _, response, error in
            let url = (response?.url ?? urlRequest.url)?.absoluteString ?? "<unknown>"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            self?.config.logger.debug("RESPONSE: %{public}d %{public}@", statusCode, url)

            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, !httpResponse.isSuccessStatusCode {
                completion(.failure(NetworkingError.nonSuccessfulStatusCode(httpResponse.statusCode)))
                return
            }

            completion(.success(()))
        }

        if let method = urlRequest.httpMethod, let url = urlRequest.url?.absoluteString {
            // swiftlint:disable:next non_optional_string_data_conversion
            let data = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? ""
            config.logger.debug("REQUEST: %{public}@ %{public}@\n%{private}@", method, url, data)
        }

        dataTask.resume()
    }

}

// MARK: - Static methods
extension NetworkClient {
    // swiftlint:disable force_unwrapping
    static let defaultSettingsHost = URL(string: "https://---")!
    // swiftlint:enable force_unwrapping

    static var defaultURLSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 5
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json; charset=utf-8"
        ]

        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        return session
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder throws in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisecondsSince1970)
        }
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension Error {
    var data: Data? {
        localizedDescription.data(using: .utf8)
    }
}

private extension Data {

    static var empty: Data {
        // swiftlint:disable:next non_optional_string_data_conversion
        "<no data or error>".data(using: .utf8) ?? Data()
    }

}
