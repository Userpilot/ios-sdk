//
//  SDKSettingsDetectorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

final class SDKSettingsDetectorTests: XCTestCase {
    
    var userpilot: MockUserpilot!
    var logger: MockLogger!
    var detector: SDKSettingsDetector!

    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot(config: config)
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolStub.self]
        let testSession = URLSession(configuration: sessionConfig)
        
        detector = SDKSettingsDetector(container: userpilot.container, session: testSession)
    }
    
    // Test 1: Should skip network when config is recent
    func testUsesCachedSettingsIfNotExpired() {
        // Arrange
        var trackedErrorLog = 0
        logger.onError = { _, _ in trackedErrorLog += 1 }
        var trackedInfoLog = 0
        logger.onInfo = { _, _ in trackedInfoLog += 1 }
        
        userpilot.storage.configurationDate = Date()
        userpilot.storage.socketURL = "https://socket.userpilot.io/ws"
        var callbackCalled = false

        // Act
        detector.fetchSettings {
            callbackCalled = true
        }

        // Assert
        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(trackedErrorLog, 0)
        XCTAssertEqual(trackedInfoLog, 0)
    }

    // Test 3: Should store settings from successful response
    func testParsesAndStoresSettingsFromValidResponse() {
        // Arrange
        let expectation = expectation(description: "callback called")

        let json = """
        { "endpoint": "https://socket.userpilot.io" }
        """.data(using: .utf8)!

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io/v1/lookups/NX-TEST")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        detector.fetchSettings {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(userpilot.storage.socketURL, "https://socket.userpilot.io" + GeneralConstants.PATH_NAME)
        XCTAssertNotNil(userpilot.storage.configurationDate)
    }

    // Test 4: Should log JSON parse error
    func testLogsJsonParseError() {
        // Arrange
        let expectation = expectation(description: "callback called")

        URLProtocolStub.response = (
            "invalid json".data(using: .utf8),
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        detector.fetchSettings {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)

        XCTAssertTrue(logger.loggedErrors.contains(where: { $0.contains("Failed to parse JSON") }))
    }

    // Test 5: Should log HTTP error status code
    func testLogsHttpErrorStatusCode() {
        // Arrange
        let expectation = expectation(description: "callback called")

        URLProtocolStub.response = (
            nil,
            HTTPURLResponse(url: URL(string: "https://find.userpilot.io")!,
                            statusCode: 500,
                            httpVersion: nil,
                            headerFields: nil),
            nil
        )

        // Act
        detector.fetchSettings {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)

        XCTAssertTrue(logger.loggedErrors.contains(where: { $0.contains("Request failed with code:") }))
    }

    // Test 6: Should log error on network failure
    func testLogsNetworkError() {
        // Arrange
        let expectation = expectation(description: "callback called")

        URLProtocolStub.response = (
            nil,
            nil,
            NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [NSLocalizedDescriptionKey: "No internet"])
        )

        // Act
        detector.fetchSettings {
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)

        XCTAssertTrue(logger.loggedErrors.contains(where: { $0.contains("Request failed") }))
    }

}
