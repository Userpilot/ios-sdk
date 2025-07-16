//
//  URLProtocolStub.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Foundation

// `URLProtocolStub` is a mock protocol that intercepts network requests
// and returns predefined responses. It is typically used in unit tests
// to simulate various network conditions without making real HTTP calls.
//
// Usage:
// 1. Assign the stubbed `response` as a tuple of (data, response, error).
// 2. Inject this protocol into `URLSessionConfiguration.protocolClasses`.
// 3. Reset `response` between test cases to avoid cross-contamination.

// swiftlint:disable all

final class URLProtocolStub: URLProtocol {

    /// The stubbed response to return when a request is intercepted.
    /// Set this before initiating the request in your test.
    static var response: (data: Data?, response: URLResponse?, error: Error?)?

    // MARK: - URLProtocol Overrides

    /// Indicates whether this protocol can handle the given request.
    /// Always returns `true` to intercept all requests.
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    /// Returns the canonical form of a request. Used for caching and comparison.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Starts loading the request by sending the stubbed response.
    override func startLoading() {
        guard let client = client else { return }

        if let response = URLProtocolStub.response {
            if let urlResponse = response.response {
                client.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
            }

            if let data = response.data {
                client.urlProtocol(self, didLoad: data)
            }

            if let error = response.error {
                client.urlProtocol(self, didFailWithError: error)
            } else {
                client.urlProtocolDidFinishLoading(self)
            }
        } else {
            client.urlProtocolDidFinishLoading(self)
        }
    }

    /// Stops loading. No cleanup needed.
    override func stopLoading() {}

    /// Resets the stored stubbed response. Call this in `tearDown()` between tests.
    static func reset() {
        response = nil
    }
}

// swiftlint:enable all
