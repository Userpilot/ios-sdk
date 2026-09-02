//
//  DeepLinkHandlerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all
final class DeepLinkHandlerTests: XCTestCase {

    private var deepLinkHandler: DeepLinkHandler!
    private var mockUserpilot: MockUserpilot!
    private var mockTopControllerGetting: MockTopControllerGetting!
    private var mockExperiencesPublisher: MockExperiencesPublisher!

    override func setUp() {
        super.setUp()
        let config = Userpilot.Config(token: "NX-12345").defaultInstance(false)
        mockUserpilot = MockUserpilot(config: config)
        mockExperiencesPublisher = mockUserpilot.experiencesPublisher
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
        if case let .preview(experienceID, queryItems) = action {
            XCTAssertEqual(experienceID, "EX-123")
            XCTAssertTrue(queryItems.isEmpty)
        } else {
            XCTFail("Expected preview action")
        }
    }

    func testAction_previewURLWithQueryItems_createsActionWithQueryItems() {
        // Arrange
        let url = URL(
            string: "userpilot-nx-12345://sdk/experience_preview/EX-123?locale_id=en-US&type=survey"
        )!

        // Act
        let action = DeepLinkHandler.Action(url: url, token: "NX-12345")

        // Assert
        if case let .preview(experienceID, queryItems) = action {
            XCTAssertEqual(experienceID, "EX-123")
            XCTAssertEqual(queryItems.count, 2)
            XCTAssertTrue(queryItems.contains(where: { $0.name == "locale_id" && $0.value == "en-US" }))
            XCTAssertTrue(queryItems.contains(where: { $0.name == "type" && $0.value == "survey" }))
        } else {
            XCTFail("Expected preview action")
        }
    }

    func testAction_invalidScheme_returnsNil() {
        let url = URL(string: "wrongscheme://sdk/experience_preview/EX-123")!
        XCTAssertNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
    }

    func testAction_invalidHost_returnsNil() {
        let url = URL(string: "userpilot-nx-12345://wronghost/experience_preview/EX-123")!
        XCTAssertNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
    }

    func testAction_invalidPath_returnsNil() {
        let url = URL(string: "userpilot-nx-12345://sdk/invalid_path/EX-123")!
        XCTAssertNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
    }

    func testAction_missingExperienceID_returnsNil() {
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/")!
        XCTAssertNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
    }

    func testAction_wrongToken_returnsNil() {
        let url = URL(string: "userpilot-nx-99999://sdk/experience_preview/EX-123")!
        XCTAssertNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
    }

    func testAction_stagingToken_acceptsProdScheme() {
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        XCTAssertNotNil(DeepLinkHandler.Action(url: url, token: "STG-NX-12345"))
    }

    func testAction_caseInsensitiveScheme_createsAction() {
        let url = URL(string: "USERPILOT-NX-12345://sdk/experience_preview/EX-123")!
        XCTAssertNotNil(DeepLinkHandler.Action(url: url, token: "NX-12345"))
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
        let url = URL(string: "https://example.com")!
        XCTAssertFalse(deepLinkHandler.didHandleURL(url))
    }

    func testDidHandleURL_validURL_triggersPreviewExperience() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
        }

        // Act
        _ = deepLinkHandler.didHandleURL(url)

        // Assert
        XCTAssertEqual(triggeredExperienceID, "EX-123")
    }

    func testDidHandleURL_validURLWithQueryItems_passesQueryItems() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(
            string: "userpilot-nx-12345://sdk/experience_preview/EX-123?locale_id=en-US&type=survey"
        )!
        var capturedQueryItems: [URLQueryItem]?
        mockExperiencesPublisher.onTriggerPreviewExperience = { _, queryItems in
            capturedQueryItems = queryItems
        }

        // Act
        _ = deepLinkHandler.didHandleURL(url)

        // Assert
        XCTAssertEqual(capturedQueryItems?.count, 2)
        XCTAssertTrue(capturedQueryItems?.contains(where: { $0.name == "locale_id" && $0.value == "en-US" }) ?? false)
        XCTAssertTrue(capturedQueryItems?.contains(where: { $0.name == "type" && $0.value == "survey" }) ?? false)
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

        // Assert
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
        _ = deepLinkHandler.didHandleURL(url)

        // Act
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        // Assert
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
        _ = deepLinkHandler.didHandleURL(url1)
        _ = deepLinkHandler.didHandleURL(url2)

        // Act
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

        // Assert
        XCTAssertEqual(triggeredExperienceIDs.count, 2)
        XCTAssertTrue(triggeredExperienceIDs.contains("EX-123"))
        XCTAssertTrue(triggeredExperienceIDs.contains("EX-456"))
    }

    func testDidHandleURL_fromBackgroundThread_handlesOnMainThread() {
        // Arrange
        mockTopControllerGetting.hasActiveWindowScenes = true
        let url = URL(string: "userpilot-nx-12345://sdk/experience_preview/EX-123")!
        var triggeredExperienceID: String?
        let expectation = expectation(description: "preview triggered")
        mockExperiencesPublisher.onTriggerPreviewExperience = { id, _ in
            triggeredExperienceID = id
            expectation.fulfill()
        }

        // Act
        DispatchQueue.global().async {
            _ = self.deepLinkHandler.didHandleURL(url)
        }

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(triggeredExperienceID, "EX-123")
    }
}

private final class MockTopControllerGetting: TopControllerGetting {
    var hasActiveWindowScenes = true
    var topViewControllerToReturn: UIViewController?

    func topViewController() -> UIViewController? {
        topViewControllerToReturn
    }
}
// swiftlint:enable all
