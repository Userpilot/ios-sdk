//
//  RemoteSourceError.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Defines error cases for remote API interactions.
//

// MARK: - RemoteSourceError

internal enum RemoteSourceError: Error {
    case invalidURL
    case invalidResponse
    case networkError(String)
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case emptyResponse

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response type"
        case .networkError(let message):
            return "Network request failed: \(message)"
        case .httpError(_, let message):
            return message
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        case .emptyResponse:
            return "Empty response body"
        }
    }
}

internal extension RemoteSourceError {
    // swiftlint:disable cyclomatic_complexity
    /// Keeps the server status mapping beside the error surfaced to settings and preview callers.
    static func fromStatusCode(_ statusCode: Int) -> RemoteSourceError {
        let message: String
        switch statusCode {
        case 400:
            message = "Bad request: The content request is invalid"
        case 401:
            message = "Unauthorized: Invalid or missing authentication"
        case 403:
            message = "Forbidden: Access to this content is denied"
        case 404:
            message = "Not found: The requested content could not be found"
        case 408:
            message = "Request timeout: The server took too long to respond"
        case 429:
            message = "Too many requests: Please try again later"
        case 500:
            message = "Server error: The server encountered an internal error"
        case 502:
            message = "Bad gateway: The server received an invalid response"
        case 503:
            message = "Service unavailable: The server is temporarily unavailable"
        case 504:
            message = "Gateway timeout: The server did not respond in time"
        default:
            message = "Request failed with status code: \(statusCode)"
        }
        return .httpError(statusCode: statusCode, message: message)
    }
    // swiftlint:enable cyclomatic_complexity
}
