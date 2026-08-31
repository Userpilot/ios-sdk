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
final class UserpilotRemoteSourceTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var logger: MockLogger!
    private var remoteSource: UserpilotRemoteSource!

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocolStub.reset()
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
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
        userpilot.storage.configurationDate = Date()
        userpilot.storage.socketURL = "https://socket.userpilot.io/mobile/v1/events/websocket"
        var callbackCalled = false
        var isSuccess = false

        // Act
        remoteSource.fetchSettings { result in
            callbackCalled = true
            if case .success = result {
                isSuccess = true
            }
        }

        // Assert
        XCTAssertTrue(callbackCalled)
        XCTAssertTrue(isSuccess)
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("Using cached SDK settings") }))
    }

    func testFetchSettings_makesNetworkRequest_whenCacheExpired() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var isSuccess = false
        userpilot.storage.configurationDate = Date().addingTimeInterval(-31 * 60)
        userpilot.storage.socketURL = "https://old-socket.userpilot.io/ws"

        URLProtocolStub.response = (
            Data(#"{ "endpoint": "https://new-socket.userpilot.io" }"#.utf8),
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
            if case .success = result {
                isSuccess = true
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isSuccess)
        XCTAssertEqual(userpilot.storage.socketURL, "https://new-socket.userpilot.io/mobile/v1/events/websocket")
    }

    func testFetchSettings_parsesAndStoresSettings_fromValidResponse() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var isSuccess = false

        URLProtocolStub.response = (
            Data(#"{ "endpoint": "https://socket.userpilot.io" }"#.utf8),
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
            if case .success = result {
                isSuccess = true
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(isSuccess)
        XCTAssertEqual(userpilot.storage.socketURL, "https://socket.userpilot.io/mobile/v1/events/websocket")
        XCTAssertNotNil(userpilot.storage.configurationDate)
        XCTAssertTrue(logger.loggedInfos.contains(where: { $0.contains("Socket URL updated") }))
    }

    // MARK: - Settings Error Tests

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
            if case .failure(let error) = result {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
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

        URLProtocolStub.response = (
            Data(#"{ "other_field": "value" }"#.utf8),
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
            if case .failure(let error) = result {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        if case .decodingError(let message) = errorType {
            XCTAssertTrue(message.contains("Failed to extract endpoint"))
        } else {
            XCTFail("Expected decodingError")
        }
    }

    func testFetchSettings_failsWithHttpError_when404() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            HTTPURLResponse(
                url: URL(string: "https://find.userpilot.io")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        // Act
        remoteSource.fetchSettings { result in
            if case .failure(let error) = result {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        if case .httpError(let code, let message) = errorType {
            XCTAssertEqual(code, 404)
            XCTAssertTrue(message.contains("Not found"))
        } else {
            XCTFail("Expected httpError")
        }
    }

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
                userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
            )
        )

        // Act
        remoteSource.fetchSettings { result in
            if case .failure(let error) = result {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        if case .networkError(let message) = errorType {
            XCTAssertTrue(message.contains("offline") || message.contains("Internet"))
        } else {
            XCTFail("Expected networkError")
        }
    }

    // MARK: - Preview Experience Tests

    func testFetchPreviewExperience_succeeds_withValidSurveyResponse() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var result: PreviewExperience?

        URLProtocolStub.response = (
            Data(
                """
                {
                    "content_type": "survey",
                    "theme": {
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
                            }
                        ],
                        "metadata": {
                            "cta_label": "Start survey"
                        },
                        "theme_data": {
                            "id": 4
                        },
                        "screens": [],
                        "screen_type": "all",
                        "locale_code": "default",
                        "time_delay": 0
                    }
                }
                """.utf8
            ),
            HTTPURLResponse(
                url: URL(string: RemoteSource.experienceBaseURL)!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: RemoteSource.experienceBaseURL,
            appToken: userpilot.config.token,
            contentType: "survey",
            contentId: "123"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            if case .success(let experience) = response {
                result = experience
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result?.contentType, "survey")
        XCTAssertNotNil(result?.survey)
        XCTAssertNotNil(result?.theme)
        assertRemoteLogsDoNotExposePreviewRequest()
    }

    func testFetchPreviewExperience_failsWithDecodingError_whenInvalidJson() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            Data("invalid json".utf8),
            HTTPURLResponse(
                url: URL(string: RemoteSource.experienceBaseURL)!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: RemoteSource.experienceBaseURL,
            appToken: userpilot.config.token,
            contentType: "survey",
            contentId: "123"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            if case .failure(let error) = response {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        if case .decodingError = errorType {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected decodingError")
        }
    }

    func testFetchPreviewExperience_failsWithHttpError_when404() {
        // Arrange
        let expectation = expectation(description: "callback called")
        var errorType: RemoteSourceError?

        URLProtocolStub.response = (
            nil,
            HTTPURLResponse(
                url: URL(string: RemoteSource.experienceBaseURL)!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            ),
            nil
        )

        let params = PreviewExperienceQueryParams(
            baseUrl: RemoteSource.experienceBaseURL,
            appToken: userpilot.config.token,
            contentType: "survey",
            contentId: "999"
        )

        // Act
        remoteSource.fetchPreviewExperience(params: params) { response in
            if case .failure(let error) = response {
                errorType = error
            }
            expectation.fulfill()
        }

        // Assert
        wait(for: [expectation], timeout: 1)
        if case .httpError(let code, _) = errorType {
            XCTAssertEqual(code, 404)
        } else {
            XCTFail("Expected httpError")
        }
        assertRemoteLogsDoNotExposePreviewRequest()
    }

    /// Preview URL includes `app_token` as a query item; never log it or the content host.
    private func assertRemoteLogsDoNotExposePreviewRequest() {
        let allLogs =
            logger.loggedDebugs + logger.loggedInfos + logger.loggedLogs + logger.loggedErrors
            + logger.loggedFaults
        XCTAssertFalse(allLogs.contains(where: { $0.contains("Request URL") }))
        XCTAssertFalse(allLogs.contains(where: { $0.contains(RemoteSource.experienceBaseURL) }))
        XCTAssertFalse(allLogs.contains(where: { $0.contains(userpilot.config.token) }))
    }
}
// swiftlint:enable all
