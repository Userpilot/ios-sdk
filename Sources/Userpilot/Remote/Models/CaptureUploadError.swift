//
//  CaptureUploadError.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Safe outcome categories for a Builder capture upload; raw transport errors never leave the remote source.
//

import Foundation

// MARK: - CaptureUploadError

internal enum CaptureUploadError: Error, Equatable {
    /// 401 `invalid_token`: the QR token is not valid. Ends capture mode.
    case invalidToken

    /// 401 `session_expired`, or any other 401: the capture session ended. Ends capture mode.
    case sessionExpired

    /// 413, or a part over the local size limit; this capture can never be sent.
    case tooLarge

    /// 422, 400, 403, 404 or another status that is not retried; sending the same bytes again cannot succeed.
    /// `reason` is a 422's `details`: a sentence naming the cause, written to be shown to the operator.
    case rejected(statusCode: Int, reason: String? = nil)

    /// 429: retried once per run after a longer wait.
    case throttled

    /// No connection, timeout, 408 or 5xx; retried within the run, then offered as Retry.
    case transient(statusCode: Int?)

    /// Cancelled by the SDK: capture mode stopped, the session was replaced or background time ran out.
    case cancelled

    /// The category name, safe to log.
    var category: String {
        switch self {
        case .invalidToken: return "invalidToken"
        case .sessionExpired: return "sessionExpired"
        case .tooLarge: return "tooLarge"
        case .rejected: return "rejected"
        case .throttled: return "throttled"
        case .transient: return "transient"
        case .cancelled: return "cancelled"
        }
    }

    /// Category, HTTP status and the backend's `details` only, for example
    /// `sessionExpired (status 401, session_expired)`. Never the token, URL, headers or body.
    func logDescription(statusCode: Int?, details: String?) -> String {
        let context = [statusCode.map { "status \($0)" }, details].compactMap { $0 }
        return context.isEmpty ? category : "\(category) (\(context.joined(separator: ", ")))"
    }
}

// MARK: - Response mapping

internal extension CaptureUploadError {

    /// The only mapping from a failed response to a category. `details` matters only for 401 and 422.
    static func from(statusCode: Int, details: String?) -> CaptureUploadError {
        switch statusCode {
        case 401: return details == "invalid_token" ? .invalidToken : .sessionExpired
        case 413: return .tooLarge
        case 422:
            let reason = details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? details : nil
            return .rejected(statusCode: statusCode, reason: reason)
        case 429: return .throttled
        case 408, 500...599: return .transient(statusCode: statusCode)
        default: return .rejected(statusCode: statusCode)
        }
    }

    /// Reads only `errors[0].details` from an error body; every other field is ignored and never logged.
    static func details(in body: Data?) -> String? {
        guard let body, !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let errors = object["errors"] as? [Any],
              let first = errors.first as? [String: Any] else { return nil }
        return first["details"] as? String
    }

    /// Maps one finished request. Any 2xx is success, even with an empty body.
    static func result(data: Data?, response: URLResponse?, error: Error?) -> Result<Void, CaptureUploadError> {
        if let error {
            return .failure((error as? URLError)?.code == .cancelled ? .cancelled : .transient(statusCode: nil))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.transient(statusCode: nil))
        }
        guard !httpResponse.isSuccessStatusCode else { return .success(()) }
        return .failure(.from(statusCode: httpResponse.statusCode, details: details(in: data)))
    }
}
