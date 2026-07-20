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

    var callbackRegistered = false
    
    override func setUpWithError() throws {
        super.setUp()
        callbackRegistered = false
        let config = Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false)
        userpilot = MockUserpilot(config: config)
       
        userpilot.socketManager.onRegisterCallback = { _ in
            self.callbackRegistered = true
        }
        
        experiencesPublisher = ExperiencesPublisher(container: userpilot.container)
    }

    override func tearDown() {
        experiencesPublisher = nil
        userpilot = nil
        super.tearDown()
    }

    // MARK: - Register Socket Callback Tests

    func testStart_shouldRegisterSocketCallback() {
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

    func testCanRequestScreenEvent_shouldReturnFalse_WhenPreviewIsPending() {
        // Arrange
        userpilot.experienceStateManager.markPreviewMode()

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
        
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
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

    func testTriggerExperience_shouldCacheManualTrigger_WhenActiveExperienceExists() {
        // Arrange
        let mockVC = MockUPExperience()
        experiencesPublisher.mockActiveExperience(experience: mockVC)
        var publishedEvent: SDKEvent?
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }

        // Act
        experiencesPublisher.triggerExperience("cached-experience-id")

        // Assert
        let expectation = XCTestExpectation(description: "manual trigger cached")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(publishedEvent)
            XCTAssertTrue(self.userpilot.experienceStateManager.hasCachedExperience())
            XCTAssertEqual(self.userpilot.experienceStateManager.getCachedExperienceId(), "cached-experience-id")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testPublishInternalSDKEvent_shouldReplayCachedManualTrigger_WhenExperienceCloses() {
        // Arrange
        let cacheExpectation = XCTestExpectation(description: "manual trigger cached")
        let replayExpectation = XCTestExpectation(description: "cached manual trigger replayed")
        let mockVC = MockUPExperience()
        experiencesPublisher.mockActiveExperience(experience: mockVC)

        var publishedExperienceIds: [String] = []
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            if let event = event as? ExperienceContentEvent {
                publishedExperienceIds.append(event.experienceId)
                replayExpectation.fulfill()
            }
        }

        experiencesPublisher.triggerExperience("cached-experience-id")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cacheExpectation.fulfill()
        }
        wait(for: [cacheExpectation], timeout: 1.0)

        let closeEvent = MockSDKEvent(
            eventName: SDKEventsName.flowExperienceDismissed.rawValue,
            eventPayload: ["mobile_content_id": 77]
        )
        closeEvent.isCloseEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(closeEvent)

        // Assert
        wait(for: [replayExpectation], timeout: 1.0)
        XCTAssertEqual(publishedExperienceIds, ["cached-experience-id"])
    }

    // MARK: - endExperience Tests

    func testEndExperience_shouldTriggerCloseOnTopViewController() {
        // Arrange
        let mockVC = MockUPExperience()
        experiencesPublisher.mockActiveExperience(experience: mockVC)
        let expectation = XCTestExpectation(description: "triggerClose was called")

        mockVC.onTriggerClose = { manualClose in
            XCTAssertTrue(manualClose)
            expectation.fulfill()
        }

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

    func testTriggerDeepLink_shouldForwardURLToLinkOpener() {
        // Arrange
        let testURL = URL(string: "https://example.com")!

        let expectation = XCTestExpectation(description: "Wait for deep link handling")
        var handledURL: URL?
        userpilot.linkOpener.onHandleURL = { url in
            handledURL = url
            expectation.fulfill()
        }

        // Act
        experiencesPublisher.triggerDeepLink(url: testURL)

        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(handledURL, testURL)
    }

    // MARK: - Socket Event Tests

    func testOnSocketEventSent_shouldUpdateCurrentScreen_ForScreenEvent() {
        // Arrange
        let screenTitle = "TestScreen"

        // Act
        experiencesPublisher.updateSceen(screenTitle)

        // Assert
        XCTAssertEqual(experiencesPublisher.mockGetCurrentScreen(), "TestScreen")
    }

    func testUpdateScreen_shouldPreservePendingPreview() {
        // Arrange
        userpilot.experienceStateManager.markPreviewMode()

        // Act
        experiencesPublisher.updateSceen("PreviewScreen")

        // Assert
        XCTAssertTrue(userpilot.experienceStateManager.isPreviewMode())
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
                XCTAssertEqual(content.id, 77)
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
                XCTAssertEqual(content.id, 1)
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

    func testOnSocketEventSent_shouldSelectSurvey_WhenHigherPriorityFlowWasSeen() {
        // Arrange
        let expectation = XCTestExpectation(description: "Unseen survey should be selected")
        let message = Message(payload: makeFlowAndSurveyPayload())
        userpilot.analyticsPublisher.onIsExperienceSeen = { experience in
            if case .flow = experience { return true }
            return false
        }

        // Act
        experiencesPublisher.onSocketEventSent(EventType.screenEvent, nil, message, true)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard case .survey(let content) = self.experiencesPublisher.getActiveMobileContent() else {
                XCTFail("Expected unseen survey content")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(content.id, 20)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testOnSocketEventSent_shouldNotCacheDuplicateActiveExperience() throws {
        // Arrange
        let expectation = XCTestExpectation(description: "Duplicate response should be ignored")
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        userpilot.experienceStateManager.markAutomaticTrigger(.flow(content: flow))
        userpilot.experienceStateManager.markActiveFromCurrentState(content: .flow(content: flow))

        // Act
        experiencesPublisher.onSocketEventSent(
            EventType.screenEvent,
            nil,
            Message(payload: MockContentFactory.makeFlowContentPayload()),
            true
        )

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(self.userpilot.experienceStateManager.getCachedExperienceContent())
            XCTAssertNil(self.experiencesPublisher.getActiveMobileContent())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testPublishInternalSDKEvent_shouldIgnoreCachedAutomaticExperience_WhenSeenBeforeReplay() throws {
        // Arrange
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        userpilot.analyticsPublisher.onIsExperienceSeen = { _ in true }
        userpilot.experienceStateManager.markCachedAutomatic(.flow(content: flow))
        let closeEvent = MockSDKEvent(
            eventName: SDKEventsName.flowExperienceDismissed.rawValue,
            eventPayload: ["mobile_content_id": flow.id]
        )
        closeEvent.isCloseEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(closeEvent)

        // Assert
        XCTAssertNil(userpilot.experienceStateManager.getCachedExperienceContent())
        XCTAssertNil(experiencesPublisher.getActiveMobileContent())
        if case .idle = userpilot.experienceStateManager.getCurrentState() {
            // Expected state.
        } else {
            XCTFail("Expected idle state after ignoring cached seen content")
        }
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
                if case .flow(let content) = result {
                    let expectedId = (mockPayload["mobile_contents"] as? [String: Any])?["id"] as? Int
                    XCTAssertEqual(content.id, expectedId)
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

        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)

        // Assert
        XCTAssertNotNil(publishedEvent)
        XCTAssertEqual(publishedEvent?.eventName, "test-event")
    }

    func testPublishInternalSDKEvent_shouldSuppressAnalytics_WhenPreviewModeIsActive() {
        // Arrange
        var publishedEvent: SDKEvent?
        userpilot.experienceStateManager.markPreviewMode()
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }

        // Act
        experiencesPublisher.publishInternalSDKEvent(MockSDKEvent(eventName: "test-event"))

        // Assert
        XCTAssertNil(publishedEvent)
    }

    func testPublishInternalSDKEvent_shouldSuppressCompletedSurvey_WhenPreviewThankYouIsShowing() {
        // Arrange
        var publishedEvent: SDKEvent?
        userpilot.experienceStateManager.markPreviewMode()
        userpilot.experienceStateManager.markActiveFromCurrentState(
            content: .survey(content: MockContentFactory.makeSurveyContent())
        )
        userpilot.experienceStateManager.markShowingThankYou()
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }
        let completedSurveyEvent = ExperienceSurveyCompletedEvent(
            surveyId: 10,
            submissionId: 20
        )

        // Act
        experiencesPublisher.publishInternalSDKEvent(completedSurveyEvent)

        // Assert
        XCTAssertNil(publishedEvent)
        XCTAssertFalse(userpilot.experienceStateManager.isPreviewMode())
    }

    func testPublishInternalSDKEvent_shouldPublishCompletedSurvey_WhenThankYouIsNotPreview() {
        // Arrange
        var publishedEvent: SDKEvent?
        userpilot.experienceStateManager.markShowingThankYou()
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { event, _ in
            publishedEvent = event
        }
        let completedSurveyEvent = ExperienceSurveyCompletedEvent(
            surveyId: 10,
            submissionId: 20
        )

        // Act
        experiencesPublisher.publishInternalSDKEvent(completedSurveyEvent)

        // Assert
        XCTAssertEqual(
            publishedEvent?.eventName,
            SDKEventsName.surveyExperienceCompleted.rawValue
        )
    }

    func testPublishInternalSDKEvent_shouldResetPreviewMode_WhenPreviewExperienceCloses() {
        // Arrange
        userpilot.experienceStateManager.markPreviewMode()
        var markExperienceAsSeen: Bool?
        userpilot.analyticsPublisher.onPublishFakeReloadScreenEvent = { _, _, markSeen in
            markExperienceAsSeen = markSeen
        }
        let closeEvent = MockSDKEvent(
            eventName: SDKEventsName.flowExperienceDismissed.rawValue,
            eventPayload: ["mobile_content_id": 77]
        )
        closeEvent.isCloseEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(closeEvent)

        // Assert
        XCTAssertFalse(userpilot.experienceStateManager.isPreviewMode())
        XCTAssertEqual(markExperienceAsSeen, false)
    }

    func testPublishInternalSDKEvent_shouldUpdateFakeReloadDate_ForCloseNPSEvent() {
        // Arrange
        userpilot.socketManager.isSocketOpened = true
        let mockEvent = MockSDKEvent(eventName: "dismiss_NPS")
        mockEvent.isCloseNPSEvent = true

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)
        let canRequest = experiencesPublisher.canRequestScreenEvent()

        // Assert
        XCTAssertFalse(canRequest)
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
        userpilot.analyticsPublisher.onPublishFakeReloadScreenEvent = { _, _, _ in
            publishFakeReloadEventCalled = true
            reloadExpectation.fulfill()
        }

        // Act
        experiencesPublisher.publishInternalSDKEvent(mockEvent)

        // Assert
        wait(for: [reloadExpectation], timeout: 1.0)
        XCTAssertTrue(publishFakeReloadEventCalled)
    }

    private func makeFlowAndSurveyPayload() -> [String: Any] {
        var payload = MockContentFactory.makeFlowContentPayload()
        payload["surveys"] = [
            "id": 20,
            "type": "list",
            "modules": [],
            "metadata": NSNull(),
            "theme_data": ["id": 22, "theme_data": NSNull()],
            "screens": ["Home"],
            "screen_type": "selected",
            "locale_code": "en",
            "time_delay": 0
        ]
        return payload
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
        experiencesPublisher.showThankYouMessage(mockSurveyContent, mockSurveyTheme, 0)

        // Assert
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let canRequest = self.experiencesPublisher.canRequestScreenEvent()
            XCTAssertFalse(canRequest) // Should be false when triggering thank you message
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Preview Experience Tests

    func testTriggerPreviewExperience_shouldFetchPreviewContentWithQueryType() {
        // Arrange
        let expectation = XCTestExpectation(description: "preview fetch requested")
        var capturedParams: PreviewExperienceQueryParams?
        userpilot.remoteSource.onFetchPreviewExperience = { params, completion in
            capturedParams = params
            completion(.failure(.emptyResponse))
            expectation.fulfill()
        }

        // Act
        experiencesPublisher.triggerPreviewExperience(
            "preview-123",
            [URLQueryItem(name: "type", value: "survey")]
        )

        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedParams?.appToken, userpilot.config.token)
        XCTAssertEqual(capturedParams?.contentType, "survey")
        XCTAssertEqual(capturedParams?.contentId, "preview-123")
        XCTAssertEqual(capturedParams?.baseUrl, RemoteSource.experienceBaseURL)
    }

    func testTriggerPreviewExperience_shouldEnterPreviewModeBeforeFetching() {
        // Arrange
        let expectation = XCTestExpectation(description: "preview mode entered")
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in
            XCTAssertTrue(self.userpilot.experienceStateManager.isPreviewMode())
            completion(.failure(.emptyResponse))
            expectation.fulfill()
        }

        // Act
        experiencesPublisher.triggerPreviewExperience("preview-123", [])

        // Assert
        wait(for: [expectation], timeout: 1.0)
    }

    func testTriggerPreviewExperience_shouldCloseActiveExperienceAsProgrammaticReset() {
        // Arrange
        let closeExpectation = XCTestExpectation(description: "active experience closed silently")
        let fetchExpectation = XCTestExpectation(description: "preview fetch requested")
        let mockVC = MockUPExperience()
        experiencesPublisher.mockActiveExperience(experience: mockVC)

        mockVC.onTriggerClose = { manualClose in
            XCTAssertFalse(manualClose)
            closeExpectation.fulfill()
        }
        userpilot.remoteSource.onFetchPreviewExperience = { _, _ in
            fetchExpectation.fulfill()
        }

        // Act
        experiencesPublisher.triggerPreviewExperience("preview-123", [])

        // Assert
        wait(for: [closeExpectation, fetchExpectation], timeout: 1.0)
    }

    func testTriggerPreviewExperience_shouldIgnoreStaleResponse_WhenNewerPreviewStarts() throws {
        // Arrange
        let fetchExpectation = XCTestExpectation(description: "both preview fetches requested")
        fetchExpectation.expectedFulfillmentCount = 2
        var completions: [
            String: (Result<PreviewExperience, RemoteSourceError>) -> Void
        ] = [:]
        userpilot.remoteSource.onFetchPreviewExperience = { params, completion in
            completions[params.contentId] = completion
            fetchExpectation.fulfill()
        }

        let latestThemeSaved = XCTestExpectation(description: "latest preview theme saved")
        var savedThemeIds: [Int] = []
        userpilot.themeHandler.onSaveTheme = { theme in
            if let id = theme.id {
                savedThemeIds.append(id)
                if id == 22 {
                    latestThemeSaved.fulfill()
                }
            }
        }

        // Act
        experiencesPublisher.triggerPreviewExperience("first", [])
        experiencesPublisher.triggerPreviewExperience("second", [])
        wait(for: [fetchExpectation], timeout: 1.0)
        completions["first"]?(.success(try makePreviewExperience(themeId: 11)))
        completions["second"]?(.success(try makePreviewExperience(themeId: 22)))

        // Assert
        wait(for: [latestThemeSaved], timeout: 1.0)
        XCTAssertFalse(savedThemeIds.contains(11))
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
        let resultExpectation = XCTestExpectation(description: "Wait for pending content check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let result = self.experiencesPublisher.getActiveMobileContent()
            // Should have some content (the last one to be processed)
            XCTAssertNotNil(result)
            resultExpectation.fulfill()
        }
        wait(for: [resultExpectation], timeout: 1.0)
    }

    private func makePreviewExperience(themeId: Int) throws -> PreviewExperience {
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
        return PreviewExperience(
            flow: flow,
            survey: nil,
            contentType: "flow",
            theme: ThemeContent(
                id: themeId,
                themeData: ThemeData(carousel: nil, slideOut: nil, survey: nil)
            )
        )
    }
}

// swiftlint:disable all
