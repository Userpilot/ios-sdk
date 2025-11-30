//
//  UserpilotRemoteSourceTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
class UserpilotRemoteSourceTests: XCTestCase {

    var userpilot: MockUserpilot!
    var logger: MockLogger!
    var remoteSource: UserpilotRemoteSource!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = Userpilot.Config(token: "NX-00000")
        logger = MockLogger()
        config.logger = logger
        userpilot = MockUserpilot(config: config)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolStub.self]
        let testSession = URLSession(configuration: sessionConfig)
        remoteSource = UserpilotRemoteSource(container: userpilot.container, session: testSession)
    }

    override func tearDownWithError() throws {
        URLProtocolStub.reset()
        userpilot = nil
        logger = nil
        remoteSource = nil
        try super.tearDownWithError()
    }

    // MARK: - Cached Configuration Tests

    func testFetchSettings_usesCachedConfiguration_whenNotExpired() {
        // Arrange
        var trackedInfoLog = 0
        logger.onInfo = { _, _ in trackedInfoLog += 1 }

        userpilot.storage.configurationDate = Date()
        userpilot.storage.socketURL = "https://socket.userpilot.io/mobile/v1/events/websocket"
        var callbackCalled = false
        var isSuccess = false

        // Act
        remoteSource.fetchSettings { result in
            callbackCalled = true
            switch result {
            case .success:
                isSuccess = true
            case .failure:
                isSuccess = false
            }
        }

        // Assert
        XCTAssertTrue(callbackCalled)
        XCTAssertTrue(isSuccess)
        XCTAssertTrue(
            logger.loggedInfos.contains(where: { $0.contains("Using cached SDK settings") }))
    }

    func testFetchSettings_makesNetworkRequest_whenCacheExpired() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var isSuccess = false

        // Set expired date (31 minutes ago)
        userpilot.storage.configurationDate = Date().addingTimeInterval(-31 * 60)
        userpilot.storage.socketURL = "https://old-socket.userpilot.io/ws"

        let json = Data(
            """
            { "endpoint": "https://new-socket.userpilot.io" }
            """.utf8)

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io/v1/lookups/NX-00000")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                isSuccess = true
            case .failure:
                isSuccess = false
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isSuccess)
        XCTAssertEqual(
            userpilot.storage.socketURL,
            "https://new-socket.userpilot.io/mobile/v1/events/websocket"
        )
    }

    func testFetchSettings_makesNetworkRequest_whenNoCacheExists() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var isSuccess = false

        userpilot.storage.configurationDate = nil
        userpilot.storage.socketURL = ""

        let json = Data(
            """
            { "endpoint": "https://socket.userpilot.io" }
            """.utf8)

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io/v1/lookups/NX-00000")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                isSuccess = true
            case .failure:
                isSuccess = false
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isSuccess)
        XCTAssertNotNil(userpilot.storage.configurationDate)
    }

    // MARK: - Successful Response Tests

    func testFetchSettings_parsesAndStoresSettings_fromValidResponse() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var isSuccess = false

        let json = Data(
            """
            { "endpoint": "https://socket.userpilot.io" }
            """.utf8)

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io/v1/lookups/NX-00000")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                isSuccess = true
            case .failure:
                isSuccess = false
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isSuccess)
        XCTAssertEqual(
            userpilot.storage.socketURL,
            "https://socket.userpilot.io/mobile/v1/events/websocket"
        )
        XCTAssertNotNil(userpilot.storage.configurationDate)
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("Socket URL updated") }))
    }

    // MARK: - JSON Parsing Error Tests

    func testFetchSettings_failsWithDecodingError_whenJsonIsInvalid() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            Data("invalid json".utf8),
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .decodingError = errorType {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected decodingError")
        }
        XCTAssertTrue(logger.loggedErrors.contains(where: { $0.contains("Failed to parse") }))
    }

    func testFetchSettings_failsWithDecodingError_whenEndpointMissing() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        let json = Data(
            """
            { "other_field": "value" }
            """.utf8)

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .decodingError(let message) = errorType {
            XCTAssertTrue(message.contains("Failed to extract endpoint"))
        } else {
            XCTFail("Expected decodingError")
        }
        XCTAssertTrue(
            logger.loggedErrors.contains(where: { $0.contains("Failed to extract endpoint") }))
    }

    // MARK: - HTTP Error Tests

    func testFetchSettings_failsWithHttpError_when400BadRequest() {
        testHttpError(statusCode: 400, expectedMessage: "Bad request")
    }

    func testFetchSettings_failsWithHttpError_when401Unauthorized() {
        testHttpError(statusCode: 401, expectedMessage: "Unauthorized")
    }

    func testFetchSettings_failsWithHttpError_when404NotFound() {
        testHttpError(statusCode: 404, expectedMessage: "Not found")
    }

    func testFetchSettings_failsWithHttpError_when500ServerError() {
        testHttpError(statusCode: 500, expectedMessage: "Server error")
    }

    func testFetchSettings_failsWithHttpError_when503ServiceUnavailable() {
        testHttpError(statusCode: 503, expectedMessage: "Service unavailable")
    }

    private func testHttpError(statusCode: Int, expectedMessage: String) {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .httpError(let code, let message) = errorType {
            XCTAssertEqual(code, statusCode)
            XCTAssertTrue(message.contains(expectedMessage))
        } else {
            XCTFail("Expected httpError")
        }
        XCTAssertTrue(
            logger.loggedErrors.contains(where: { $0.contains("Request failed with code:") }))
    }

    // MARK: - Network Error Tests

    func testFetchSettings_failsWithNetworkError_whenNoInternet() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            nil,
            NSError(
                domain: NSURLErrorDomain,
                code: -1009,
                userInfo: [
                    NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
                ]
            )
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .networkError(let message) = errorType {
            XCTAssertTrue(message.contains("offline") || message.contains("Internet"))
        } else {
            XCTFail("Expected networkError")
        }
        XCTAssertTrue(
            logger.loggedErrors.contains(where: { $0.contains("Network request failed") }))
    }

    func testFetchSettings_failsWithNetworkError_whenTimeout() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            nil,
            NSError(
                domain: NSURLErrorDomain,
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "The request timed out."]
            )
        )

        // Act
        remoteSource.fetchSettings { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .networkError(let message) = errorType {
            XCTAssertTrue(message.contains("timed out"))
        } else {
            XCTFail("Expected networkError")
        }
    }

    // MARK: - Preview Experience Tests
    // swiftlint:disable:next superfluous_disable_command
    func testFetchPreviewExperience_succeeds_withValidSurveyResponse() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var result: PreviewExperience?

        let json = Data(
            """
            {
                "content_type": "survey",
                "survey": {
                    "id": 12,
                    "token": "survey:12",
                    "type": "step",
                    "modules": [
                        {
                            "id": 101,
                            "type": "likert_scale",
                            "question": "How satisfied are you with the app?",
                            "is_required": true,
                            "metadata": {
                                "high_score": "Very satisfied",
                                "low_score": "Not at all",
                                "range": 5,
                                "type": "stars"
                            },
                            "logic": null,
                            "button_label": "Next"
                        },
                        {
                            "id": 102,
                            "type": "open_text",
                            "question": "Tell us why you chose that score",
                            "placeholder": "Your feedback…",
                            "is_required": false,
                            "button_label": "Submit"
                        }
                    ],
                    "metadata": {
                        "cta_label": "Start survey"
                    },
                    "theme_data": {
                        "id": 4,
                        "theme_data": {
                            "button": {
                                "background_color": "#4E4CE8",
                                "border_color": "#4E4CE8",
                                "label_color": "#FFFFFF"
                            },
                            "colors": {
                                "background_color": "#FFFFFF",
                                "text_color": "#000000",
                                "title_color": "#000000"
                            },
                            "general": {
                                "font_family": "Default",
                                "content_alignment": "top"
                            },
                            "progress": {
                                "enabled": true,
                                "color": "#4E4CE8",
                                "color_type": "automatic"
                            }
                        }
                    },
                    "screens": [],
                    "screen_type": "all",
                    "locale_code": "default",
                    "time_delay": 0
                }
            }
            """.utf8)

        URLProtocolStub.response = (
            json,
            HTTPURLResponse(
                url: URL(string: "https://appex-dev-nxtapp-14664.userpilot.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content",
            appToken: "NX-00000",
            contentType: "survey",
            contentId: "123"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            switch response {
            case .success(let experience):
                result = experience
            case .failure:
                break
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.contentType, "survey")
        XCTAssertNotNil(result?.survey)
    }

    func testFetchPreviewExperience_failsWithDecodingError_whenInvalidJson() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            Data("invalid json".utf8),
            HTTPURLResponse(
                url: URL(string: "https://appex-dev-nxtapp-14664.userpilot.io")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content",
            appToken: "NX-00000",
            contentType: "survey",
            contentId: "123"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            switch response {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .decodingError = errorType {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected decodingError")
        }
        XCTAssertTrue(
            logger.loggedErrors.contains(where: {
                $0.contains("Failed to process Preview experience")
            }))
    }

    func testFetchPreviewExperience_failsWithHttpError_when404() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            HTTPURLResponse(
                url: URL(string: "https://appex-dev-nxtapp-14664.userpilot.io")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: "https://appex-dev-nxtapp-14664.userpilot.io/api/v1/public/content",
            appToken: "NX-00000",
            contentType: "survey",
            contentId: "999"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            switch response {
            case .success:
                break
            case .failure(let error):
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(errorType)
        if case .httpError(let code, _) = errorType {
            XCTAssertEqual(code, 404)
        } else {
            XCTFail("Expected httpError")
        }
        XCTAssertTrue(
            logger.loggedErrors.contains(where: {
                $0.contains("Failed to fetch preview experience")
            }))
    }
}
// swiftlint:enable all
