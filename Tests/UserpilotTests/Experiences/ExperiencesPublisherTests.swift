//
//  ExperiencesPublisher.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 15/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

// swiftlint:disable all

final class ExperiencesPublisherTests: XCTestCase {

    var experiencesPublisher: ExperiencesPublisher!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        super.setUp()
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        experiencesPublisher = ExperiencesPublisher(container: userpilot.container)
    }

    override func tearDown() {
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Register Socket Callback Tests

    func testStart_shouldRegisterSocketCallback() {
        // Arrange
        var callbackRegistered = false
        userpilot.socketManager.onRegisterCallback = { _ in
            callbackRegistered = true
        }

        // Act
        experiencesPublisher.start()

        // Assert
        XCTAssertTrue(callbackRegistered)
    }

    // MARK: - canRequestScreenEvent Tests

    func testCanRequestScreenEvent_shouldReturnTrue_WhenNoActiveExperience() {
        // Act
        let result = experiencesPublisher.canRequestScreenEvent()

        // Assert
        XCTAssertTrue(result)
    }

    func testCanRequestScreenEvent_shouldReturnFalse_WhenOneSecondFlagIsActive() {
        // Arrange
        experiencesPublisher.activeOneTimeFlag()

        // Act
        let result = experiencesPublisher.canRequestScreenEvent()

        // Assert
        XCTAssertFalse(result)
    }

    // MARK: - triggerExperience Tests

    func testTriggerExperience_shouldPublishEvent_WhenNoActiveExperience() {
        // Arrange
        let experienceId = "test-experience-id"
        var publishedEvent: SDKEvent?
        let expectation = XCTestExpectation(description: "Event should be published")
        
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _, _ in
            publishedEvent = event
            expectation.fulfill()
        }

        // Act
        experiencesPublisher.triggerExperience(experienceId)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(publishedEvent)
        XCTAssertTrue(publishedEvent is ExperienceContentEvent)
        if let event = publishedEvent as? ExperienceContentEvent {
            XCTAssertEqual(event.experienceId, experienceId)
        }
    }

    // MARK: - endExperience Tests

    func testEndExperience_shouldTriggerCloseOnTopViewController() {
        // Arrange
        let mockVC = MockUPExperience()
        let expectation = XCTestExpectation(description: "triggerClose was called")

        mockVC.onTriggerClose = { manualClose in
            XCTAssertTrue(manualClose)
            expectation.fulfill()
        }

        experiencesPublisher.topViewControllerProvider = { return mockVC }

        // Act
        experiencesPublisher.endExperience(manualClose: true)

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - getActiveMobileContent Tests

    func testGetActiveMobileContent_shouldReturnNil_WhenNoActiveContent() {
        // Act
        let result = experiencesPublisher.getActiveMobileContent()

        // Assert
        XCTAssertNil(result)
    }

    func testGetActiveMobileContent_shouldReturnAndClearContent_WhenContentExists() {
        // Arrange
        let expectation = XCTestExpectation(description: "Content should be processed")
        let mockPayload: [String: Any?] = MockContentFactory.makeFlowContentPayload()
        let message = Message(payload: ["payload": mockPayload])

        userpilot.analyticsPublisher.canRequestEvent = true

        // Act
        experiencesPublisher.onNewMessage(message)
        experiencesPublisher.onNewMessage(message)
        
        // Wait for async processing to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            XCTAssertNotNil(result)

            // Wait longer for async clearing to happen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let secondResult = self.experiencesPublisher.getActiveMobileContent()
                XCTAssertNil(secondResult)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - triggerDeepLink Tests

    func testTriggerDeepLink_shouldCallNavigationDelegate_WhenDelegateExists() {
        // Arrange
        let testURL = URL(string: "https://example.com")!
        let mockDelegate = MockNavigationDelegate()
        userpilot.navigationDelegate = mockDelegate

        var navigatedURL: URL?
        mockDelegate.onNavigate = { url in
            navigatedURL = url
        }

        let expectation = XCTestExpectation(description: "Wait for deep link handling")

        // Act
        experiencesPublisher.triggerDeepLink(url: testURL)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertEqual(navigatedURL, testURL)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Socket Event Tests

    func testOnSocketEventSent_shouldUpdateCurrentScreen_ForScreenEvent() {
        // Arrange
        let screenTitle = "TestScreen"
        let payload: [String: Any]? = [AnalyticsPublisher.screenTitleProperty: screenTitle]
        let message = Message(payload: ["test": "data"])

        // Act
        experiencesPublisher.onSocketEventSent(EventType.screenEvent, payload, message, true)

        // Assert
        XCTAssertEqual(experiencesPublisher.mockGetCurrentScreen(), "TestScreen")
    }

    func testOnSocketEventSent_shouldSaveTheme_ForThemeEvent() {
        // Arrange
        let expectation = XCTestExpectation(description: "Theme should be saved")
        let themeData: [String: Any] = [
            "id": 123,
            "theme_data": [
                "carousel": [:],
                "slideout": [:],
                "survey": [:]
            ]
        ]
        let message = Message(payload: themeData)

        var savedTheme: ThemeContent?
        userpilot.themeHandler.onSaveTheme = { theme in
            savedTheme = theme
            expectation.fulfill()
        }

        // Act
        experiencesPublisher.onSocketEventSent(SDKEventsName.fetchExperienceTheme.rawValue, nil, message, true)

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(savedTheme)
    }

    func testOnSocketEventSent_shouldSetFlowContent_ForValidFlowResponse() {
        // Arrange
        let expectation = XCTestExpectation(description: "Flow content should be processed")
        let message = Message(payload: MockContentFactory.makeFlowContentPayload())

        // Act
        experiencesPublisher.onSocketEventSent(EventType.screenEvent, nil, message, true)

        // Wait for async processing to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            
            // Assert
            XCTAssertNotNil(result)
            if case .flow(let content) = result {
                XCTAssertEqual(content.token, "mobile:77")
            } else {
                XCTFail("Expected flow content")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnSocketEventSent_shouldSetSurveyContent_ForValidSurveyResponse() {
        // Arrange
        let expectation = XCTestExpectation(description: "Survey content should be processed")
        let surveyData: [String: Any] = [
            "surveys": [
                "id": 1,
                "token": "survey-123",
                "type": "step",
                "modules": [],
                "theme_data": ["id": 1],
                "screens": [],
                "screen_type": "all",
                "locale_code": "en",
                "time_delay": 0
            ]
        ]
        let message = Message(payload: surveyData)

        // Act
        experiencesPublisher.onSocketEventSent(EventType.screenEvent, nil, message, true)

        // Wait for async processing to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            
            // Assert
            XCTAssertNotNil(result)
            if case .survey(let content) = result {
                XCTAssertEqual(content.token, "survey-123")
            } else {
                XCTFail("Expected survey content")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnSocketEventSent_shouldSetNPSContent_ForValidNPSResponse() {
        // Arrange
        let expectation = XCTestExpectation(description: "NPS content should be processed")
        let message = Message(payload: MockContentFactory.makeNPSContentPayload())

        // Act
        experiencesPublisher.onSocketEventSent(EventType.screenEvent, nil, message, true)

        // Wait for async processing to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            
            // Assert
            XCTAssertNotNil(result)
            if case .nps(let content) = result {
                XCTAssertEqual(content.localeCode, "en")
                XCTAssertEqual(content.timeDelay, 0)
                XCTAssertEqual(content.content.survey.question, "How likely are you to recommend us to a friend?")
            } else {
                XCTFail("Expected NPS content")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - onNewMessage Tests

    func testOnNewMessage_shouldProcessFlowContent_WhenValidPayload() {
        // Arrange
        let expectation = XCTestExpectation(description: "Flow content should be processed")
        let mockPayload: [String: Any?] = MockContentFactory.makeFlowContentPayload()
        let message = Message(payload: ["payload": mockPayload])

        // Act
        experiencesPublisher.onNewMessage(message)

        // Wait for async processing to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnNewMessage_shouldNotProcessContent_WhenRequestIdExists() {
        // Arrange
        let payload: [String: Any] = [
            "mobile_contents": ["test": "data"],
            "request_id": 123
        ]
        let message = Message(payload: ["payload": payload])

        // Act
        experiencesPublisher.onNewMessage(message)

        // Assert
        let result = experiencesPublisher.getActiveMobileContent()
        XCTAssertNil(result)
    }

    func testOnNewMessage_shouldNotProcessContent_WhenActiveExperienceExists() {
        // Arrange
        let expectation = XCTestExpectation(description: "First content should be processed, second should not")
        let mockPayload: [String: Any?] = MockContentFactory.makeFlowContentPayload()
        let firstMessage = Message(payload: ["payload": mockPayload])

        // Process first message
        experiencesPublisher.onNewMessage(firstMessage)

        // Wait for first message to be processed, then try second message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Now try to process another message - this should be ignored due to pending experience
            let secondMessage = Message(payload: ["payload": mockPayload])
            self.experiencesPublisher.onNewMessage(secondMessage)
            
            // Wait a bit more and check result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let result = self.experiencesPublisher.getActiveMobileContent()
                // Should still be the first (flow) content
                if case .flow(_) = result {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Expected flow content to remain")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - publishInternalSDKEvent Tests

    func testPublishInternalSDKEvent_shouldCallAnalyticsPublisher() {
        // Arrange
        let mockEvent = MockSDKEvent(eventName: "test-event", eventPayload: ["key": "value"])
        var publishedEvent: SDKEvent?
        var isExperienceEvent: Bool?

        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, isExpEvent, _ in
            publishedEvent = event
            isExperienceEvent = isExpEvent
        }

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)

        // Assert
        XCTAssertNotNil(publishedEvent)
        XCTAssertEqual(publishedEvent?.eventName, "test-event")
        XCTAssertEqual(isExperienceEvent, true)
    }

    func testPublishInternalSDKEvent_shouldActivateFlag_ForCloseNPSEvent() {
        // Arrange
        let mockEvent = MockSDKEvent(eventName: "dismiss_NPS")
        mockEvent.isCloseNPSEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)
        let canRequest = experiencesPublisher.canRequestScreenEvent()

        // Assert
        XCTAssertFalse(canRequest) // oneSecondFlag should be active
    }

    func testPublishInternalSDKEvent_shouldHandleCloseEvent_WithDeepLink() {
        // Arrange
        let mockEvent = MockSDKEvent(eventName: "close-event", hasDeepLink: true)
        mockEvent.isCloseEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)
        let result = experiencesPublisher.getActiveMobileContent()

        // Assert
        XCTAssertNil(result)
    }

    func testPublishInternalSDKEvent_shouldHandleCloseEvent_withoutDeepLink() {
        // Arrange
        experiencesPublisher.mockSetCurrentScreen(title: "main_screen")
        userpilot.analyticsPublisher.screenEntity = ScreenViewEntity(
            event: Event(type: .screen("main_screen")),
            seenExperiences: Set(),
            seenSurveys: Set()
        )
        let mockEvent = MockSDKEvent(eventName: "dismissed_mobile_content", hasDeepLink: false)
        mockEvent.isCloseEvent = true

        // The closure you care about will eventually publish a fake reload,
        // so watch for that as proof the debounced block ran.
        let reloadExpectation = XCTestExpectation(description: "debounced fake‑reload published")
        var publishFakeReloadEventCalled = false
        userpilot.analyticsPublisher.onPublishFakeReloadScreenEvent = { _, _ in
            publishFakeReloadEventCalled = true
            reloadExpectation.fulfill()
        }

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)

        // Assert
        wait(for: [reloadExpectation], timeout: 1.0)
        XCTAssertTrue(publishFakeReloadEventCalled)
    }

    // MARK: - activeOneTimeFlag Tests

    func testActiveOneTimeFlag_shouldPreventScreenEvents() {
        // Arrange
        let initialCanRequest = experiencesPublisher.canRequestScreenEvent()
        XCTAssertTrue(initialCanRequest)

        // Act
        experiencesPublisher.activeOneTimeFlag()

        // Assert
        let finalCanRequest = experiencesPublisher.canRequestScreenEvent()
        XCTAssertFalse(finalCanRequest)
    }

    // MARK: - showThankYouMessage Tests

    func testShowThankYouMessage_shouldTriggerThankYouView() {
        // Arrange
        let mockSurveyContent = MockContentFactory.makeSurveyContent()
        let mockSurveyTheme = MockContentFactory.makeSurveyTheme()

        let expectation = XCTestExpectation(description: "Wait for thank you message")
        let mockVC = MockUPExperience()
        experiencesPublisher.topViewControllerProvider = { return mockVC }

        // Act
        experiencesPublisher.showThankYouMessage(mockSurveyContent, mockSurveyTheme)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let canRequest = self.experiencesPublisher.canRequestScreenEvent()
            XCTAssertFalse(canRequest) // Should be false when triggering thank you message
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Thread Safety Tests

    func testThreadSafety_multipleSimultaneousAccess() {
        // Arrange
        let expectation = XCTestExpectation(description: "Wait for concurrent operations")
        expectation.expectedFulfillmentCount = 10

        // Act
        for _ in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                let mockPayload: [String: Any?] = MockContentFactory.makeFlowContentPayload()
                let message = Message(payload: ["payload": mockPayload])
                self.experiencesPublisher.onNewMessage(message)
                expectation.fulfill()
            }
        }

        // Assert
        wait(for: [expectation], timeout: 2.0)

        // Verify that we still have valid state after concurrent access
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            // Should have some content (the last one to be processed)
            XCTAssertNotNil(result)
        }
    }
}

// swiftlint:disable all
