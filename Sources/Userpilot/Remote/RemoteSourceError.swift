//
//  RemoteSourceError.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
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
