//
//  DeepLinkHandlerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest

@testable import Userpilot

class DeepLinkHandlerTests: XCTestCase {

    var deepLinkHandler: DeepLinkHandler!
    var mockUserpilot: MockUserpilot!
    var mockTopControllerGetting: MockTopControllerGetting!
    var mockExperiencesPublisher: MockExperiencesPublisher!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-12345")
        mockUserpilot = MockUserpilot(config: config)

        // Use the mock experiences publisher from MockUserpilot
        mockExperiencesPublisher = mockUserpilot.experiencesPublisher

        // Create and register a real DeepLinkHandler for testing
        deepLinkHandler = DeepLinkHandler(container: mockUserpilot.container)

        mockTopControllerGetting = MockTopControllerGetting()
        deepLinkHandler.topControllerGetting = mockTopControllerGetting
    }

    override func tearDown() {
        deepLinkHandler = nil
        mockUserpilot = nil
        mockTopControllerGetting = nil
        mockExperiencesPublisher = nil
        super.tearDown()
    }

    // MARK: - Action Init Tests

    func testAction_validPreviewURL_createsAction() {
        // Arrange
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNotNil(action)
        if case let .preview(experienceID, queryItems) = action! {
            XCTAssertEqual(experienceID, "EX-123")
            XCTAssertTrue(queryItems.isEmpty)
        } else {
            XCTFail("Expected preview action")
        }
    }

    func testAction_previewURLWithLocale_createsActionWithQueryItems() {
        // Arrange
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123?locale_id=en-US")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNotNil(action)
        if case let .preview(experienceID, queryItems) = action! {
            XCTAssertEqual(experienceID, "EX-123")
            XCTAssertEqual(queryItems.count, 1)
            XCTAssertEqual(queryItems.first?.name, "locale_id")
            XCTAssertEqual(queryItems.first?.value, "en-US")
        } else {
            XCTFail("Expected preview action")
        }
    }

    func testAction_invalidScheme_returnsNil() {
        // Arrange
        let url = URL(string: "wrongscheme://sdk/experience_preview/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    func testAction_invalidHost_returnsNil() {
        // Arrange
        let url = URL(string: "userpilot-nx-12345://wronghost/experience_preview/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    func testAction_invalidPath_returnsNil() {
        // Arrange
        let url = URL(string: "userpilot-nx-12345://sdk/invalid_path/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    func testAction_missingExperienceID_returnsNil() {
        // Arrange
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    func testAction_wrongToken_returnsNil() {
        // Arrange
        let url = URL(string: "userpilot-nx-99999://sdk/experience_preview/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    func testAction_caseInsensitiveScheme_notWorks() {
        // Arrange
        let url = URL(string: "USERPILOT-NX-12345://sdk/experience_preview/EX-123")!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        XCTAssertNil(action)
    }

    // MARK: - DidHandleURL Tests

    func testDidHandleURL_validURL_returnsTrue() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!

        // Act
        let handled = deepLinkHandler.didHandleURL(url)

        // Assert
        XCTAssertTrue(handled)
    }

    func testDidHandleURL_invalidURL_returnsFalse() {
        // Arrange
        let url = URL(string: "https://example.com")!

        // Act
        let handled = deepLinkHandler.didHandleURL(url)

        // Assert
        XCTAssertFalse(handled)
    }

    func testDidHandleURL_validURL_triggersExperience() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
        }

        // Act
        _ = deepLinkHandler.didHandleURL(url)

        // Wait for main thread dispatch
        let expectation = XCTestExpectation(description: "Experience triggered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertEqual(triggeredExperienceID, "EX-123")
    }

    func testDidHandleURL_validURLWithQueryItems_passesQueryItems() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(
            string:
                "userpilot-nx-12345://sdk/experience_preview/EX-123?locale_id=en-US&variant=test")!
        var capturedQueryItems: [URLQueryItem]?
        mockExperiencesPublisher.onTriggerPreviewExperience = { _, queryItems in
            capturedQueryItems = queryItems
        }

        // Act
        _ = deepLinkHandler.didHandleURL(url)

        // Wait for main thread dispatch
        let expectation = XCTestExpectation(description: "Experience triggered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert
        XCTAssertNotNil(capturedQueryItems)
        XCTAssertEqual(capturedQueryItems?.count, 2)
        XCTAssertTrue(
            capturedQueryItems?.contains(where: { $0.name == "locale_id" && $0.value == "en-US" })
                ?? false)
        XCTAssertTrue(
            capturedQueryItems?.contains(where: { $0.name == "variant" && $0.value == "test" })
                ?? false)
    }

    // MARK: - Deferred Action Tests

    func testDidHandleURL_whenScenesNotActive_defersAction() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = false
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
        }

        // Act
        _ = deepLinkHandler.didHandleURL(url)

        // Wait a bit
        let expectation = XCTestExpectation(description: "Wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - should not trigger immediately
        XCTAssertNil(triggeredExperienceID)
    }

    func testDidHandleURL_deferredAction_triggersWhenSceneActivates() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = false
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
        }

        // Act - Handle URL while scenes are not active
        _ = deepLinkHandler.didHandleURL(url)

        // Wait a bit
        var expectation = XCTestExpectation(description: "Wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - should not trigger yet
        XCTAssertNil(triggeredExperienceID)

        // Act - Simulate scene activation
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        // Wait for notification handling
        expectation = XCTestExpectation(description: "Scene activated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - should trigger after scene activation
        XCTAssertEqual(triggeredExperienceID, "EX-123")
    }

    func testDidHandleURL_multipleDeferredActions_allTriggerWhenSceneActivates() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = false
        let url1 = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        let url2 = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-456")!
        var triggeredExperienceIDs: [String] = []
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceIDs.append(id)
        }

        // Act - Handle multiple URLs while scenes are not active
        _ = deepLinkHandler.didHandleURL(url1)
        _ = deepLinkHandler.didHandleURL(url2)

        // Wait a bit
        var expectation = XCTestExpectation(description: "Wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - should not trigger yet
        XCTAssertTrue(triggeredExperienceIDs.isEmpty)

        // Act - Simulate scene activation
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        // Wait for notification handling
        expectation = XCTestExpectation(description: "Scene activated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - both should trigger (note: Set doesn't guarantee order)
        XCTAssertEqual(triggeredExperienceIDs.count, 2)
        XCTAssertTrue(triggeredExperienceIDs.contains("EX-123"))
        XCTAssertTrue(triggeredExperienceIDs.contains("EX-456"))
    }

    // MARK: - Thread Safety Tests

    func testDidHandleURL_fromBackgroundThread_handlesCorrectly() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
        }

        let expectation = XCTestExpectation(description: "Background thread handling")

        // Act - Handle from background thread
        DispatchQueue.global().async {
            _ = self.deepLinkHandler.didHandleURL(url)

            // Wait for main thread dispatch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(triggeredExperienceID, "EX-123")
    }

    // MARK: - Action Hashable Tests

    func testAction_hashable_sameActionsAreEqual() {
        // Arrange
        let action1 = DeepLinkHandler.Action.preview(experienceID: "EX-123", queryItems: [])
        let action2 = DeepLinkHandler.Action.preview(experienceID: "EX-123", queryItems: [])

        // Assert
        XCTAssertEqual(action1, action2)
        XCTAssertEqual(action1.hashValue, action2.hashValue)
    }

    func testAction_hashable_differentActionsAreNotEqual() {
        // Arrange
        let action1 = DeepLinkHandler.Action.preview(experienceID: "EX-123", queryItems: [])
        let action2 = DeepLinkHandler.Action.preview(experienceID: "EX-456", queryItems: [])

        // Assert
        XCTAssertNotEqual(action1, action2)
    }

    func testAction_hashable_sameIDDifferentQueryItems_areNotEqual() {
        // Arrange
        let queryItem1 = URLQueryItem(name: "locale_id", value: "en-US")
        let queryItem2 = URLQueryItem(name: "locale_id", value: "fr-FR")
        let action1 = DeepLinkHandler.Action.preview(
            experienceID: "EX-123", queryItems: [queryItem1])
        let action2 = DeepLinkHandler.Action.preview(
            experienceID: "EX-123", queryItems: [queryItem2])

        // Assert
        XCTAssertNotEqual(action1, action2)
    }
}
