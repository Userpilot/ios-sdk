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

    /// Holds the response back this long, so a test can cancel a request that is in flight.
    static var responseDelay: TimeInterval = 0

    /// How many requests were stopped (cancelled) before they finished.
    static var stoppedCount: Int { lock.withLock { stopped } }

    private static let lock = NSLock()
    private static var stopped = 0
    private var isStopped = false
    private var didRespond = false

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

    /// Starts loading the request by sending the stubbed response, after `responseDelay` when set.
    override func startLoading() {
        let delay = URLProtocolStub.responseDelay
        guard delay > 0 else { respond(); return }
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let shouldRespond = URLProtocolStub.lock.withLock { () -> Bool in
                guard !self.isStopped else { return false }
                self.didRespond = true
                return true
            }
            if shouldRespond { self.respond() }
        }
    }

    private func respond() {
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

    /// Called when the request finishes or is cancelled; a delayed response that hasn't been sent is dropped.
    override func stopLoading() {
        URLProtocolStub.lock.withLock {
            if URLProtocolStub.responseDelay > 0, !isStopped, !didRespond { URLProtocolStub.stopped += 1 }
            isStopped = true
        }
    }

    /// Resets the stored stubbed response. Call this in `tearDown()` between tests.
    static func reset() {
        response = nil
        responseDelay = 0
        lock.withLock { stopped = 0 }
    }
}

// swiftlint:enable all
