//
//  ExperiencesPublisherTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Verifies admission, request ownership and renderer dismissal without live networking or animations.
//

import XCTest
@testable import Userpilot

final class ExperiencesPublisherTests: XCTestCase {
    var publisher: ExperiencesPublisher!
    var userpilot: MockUserpilot!
    var host: MockExperiencePresentationHost!
    var displayDelay: MockExperienceDisplayDelay!
    var callbackRegistered = false
    var publishedEvents: [SDKEvent] = []
    var reloadCount = 0

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        // Resolve real renderer ViewModels against the real publisher, but keep the presentation host
        // independent from the facade's UIKit overlay so no window or animation enters these tests.
        userpilot.container.owner = nil
        userpilot.socketManager.onRegisterCallback = { [weak self] _ in self?.callbackRegistered = true }
        userpilot.themeHandler.onGetThemeById = { _ in ThemeData(carousel: nil, slideOut: nil, survey: nil) }
        userpilot.analyticsPublisher.onPublishInternalSDKEvent = { [weak self] in self?.publishedEvents.append($0) }
        userpilot.analyticsPublisher.onPublishFakeReloadScreenEvent = { [weak self] _, _, _ in
            self?.reloadCount += 1
            return true
        }
        publisher = ExperiencesPublisher(container: userpilot.container)
        userpilot.container.register(ExperiencesPublishing.self, value: publisher!)
        host = MockExperiencePresentationHost()
        publisher.topViewControllerProvider = { [weak self] in self?.host }
        displayDelay = MockExperienceDisplayDelay()
        publisher.mockSetDelayUtils(displayDelay)
        publisher.updateScreen("Home")
        publisher.mockWaitForQueue()
    }

    override func tearDown() {
        publisher.logout()
        settle()
        publisher = nil
        host = nil
        displayDelay = nil
        userpilot = nil
        publishedEvents.removeAll()
        reloadCount = 0
        super.tearDown()
    }

    func testInitializationRegistersSocketCallback() {
        XCTAssertTrue(callbackRegistered)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertNil(publisher.getActiveMobileContent())
    }

    func testManualRequestOwnsAdmissionWhileFetchingContent() throws {
        let request = try beginManual()
        XCTAssertEqual((request.event as? ExperienceContentEvent)?.experienceId, "flow-a")
        XCTAssertTrue(request.shouldSend())
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    func testBusyManualRequestIsDroppedAndNeverReplayed() throws {
        let request = try beginManual()
        publisher.triggerExperience("flow-b")
        publisher.mockWaitForQueue()
        XCTAssertEqual(userpilot.analyticsPublisher.requests.count, 1)
        request.completion?(Message(), false)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(userpilot.analyticsPublisher.requests.count, 1)
    }

    func testEmptyManualResponseReleasesAdmission() throws {
        try beginManual().completion?(Message(), true)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testFailedManualResponseReleasesAdmission() throws {
        try beginManual().completion?(Message(), false)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testManualResponseSchedulesContentAndShowsItOnlyAfterDelay() throws {
        try beginManual().completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
        XCTAssertNil(host.presentedExperience)
        try presentScheduled()
        XCTAssertTrue(host.presentedExperience is CarouselExperienceViewController)
        XCTAssertEqual(publisher.getActiveMobileContent()?.experienceId(), 77)
    }

    func testMissingThemeRequestsThemeBeforeDisplay() throws {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        let request = try XCTUnwrap(userpilot.analyticsPublisher.requests.last)
        XCTAssertTrue(request.event is ThemeContentEvent)
        XCTAssertFalse(displayDelay.hasAction)
        var themeSaved = false
        userpilot.themeHandler.onSaveTheme = { _ in themeSaved = true }
        request.completion?(Message(payload: ["id": 1, "theme_data": [:]]), true)
        publisher.mockWaitForQueue()
        XCTAssertTrue(themeSaved)
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testFailedThemeResponseReleasesAdmission() throws {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try XCTUnwrap(userpilot.analyticsPublisher.requests.last).completion?(Message(), false)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testWrongThemeResponseCannotPresentContent() throws {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try XCTUnwrap(userpilot.analyticsPublisher.requests.last).completion?(
            Message(payload: ["id": 999, "theme_data": [:]]), true
        )
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
    }

    func testMissingThemeWhileOfflineReleasesAdmission() {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        userpilot.analyticsPublisher.canRequestEvent = false
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertTrue(userpilot.analyticsPublisher.requests.isEmpty)
    }

    func testSharedThemeNotificationsDoNotResolveAnotherOperationsRequest() {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        publisher.onSocketEventSent(SDKEventsName.fetchExperienceTheme.rawValue, nil,
                                    Message(payload: ["id": 1, "theme_data": [:]]), true)
        publisher.mockWaitForQueue()
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

}

extension ExperiencesPublisherTests {
    func testScreenResponseForPreviousScreenIsDropped() {
        publisher.updateScreen("Settings")
        publisher.mockWaitForQueue()
        receiveScreen(MockContentFactory.makeFlowContentPayload(), screen: "Home")
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testFailedScreenResponseIsDropped() {
        publisher.onSocketEventSent(Constants.Event.screenEvent, nil,
                                    Message(payload: MockContentFactory.makeFlowContentPayload()), false)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testScreenResponseDoesNotChangeNavigationContext() {
        receiveScreen(MockContentFactory.makeFlowContentPayload(), screen: "Other")
        XCTAssertEqual(publisher.getCurrentScreen, "Home")
    }

    func testBackendSelectedFlowIsNotFilteredByLocalSeenHistory() {
        userpilot.analyticsPublisher.onIsExperienceSeen = { _ in true }
        var response = MockContentFactory.makeFlowContentPayload()
        response.merge(MockContentFactory.makeSurveyContentPayload()) { original, _ in original }
        receiveScreen(response)
        XCTAssertTrue(displayDelay.hasAction)
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    func testTrackMessageWithNullRequestIDStartsContent() {
        var response = MockContentFactory.makeFlowContentPayload()
        response["request_id"] = NSNull()
        publisher.onNewMessage(Message(payload: ["payload": response]))
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testTrackMessageWithNumericRequestIDIsIgnored() {
        var response = MockContentFactory.makeFlowContentPayload()
        response["request_id"] = 123
        publisher.onNewMessage(Message(payload: ["payload": response]))
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testTrackMessageWithoutRequestIDIsIgnored() {
        var response = MockContentFactory.makeFlowContentPayload()
        response.removeValue(forKey: "request_id")
        publisher.onNewMessage(Message(payload: ["payload": response]))
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testBusyPublisherDropsScreenAndTrackContent() throws {
        let request = try beginManual()
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        var response = MockContentFactory.makeFlowContentPayload()
        response["request_id"] = NSNull()
        publisher.onNewMessage(Message(payload: ["payload": response]))
        publisher.mockWaitForQueue()
        request.completion?(Message(), false)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
    }

    func testSocketCloseAbandonsContentFetchAndCancelsItsRequest() throws {
        let request = try beginManual()
        publisher.onSocketClosed()
        publisher.mockWaitForQueue()
        XCTAssertFalse(request.shouldSend())
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testSocketCloseAbandonsThemeFetch() {
        userpilot.themeHandler.onGetThemeById = { _ in nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        publisher.onSocketClosed()
        publisher.mockWaitForQueue()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testSocketClosePreservesAlreadyScheduledContent() {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        publisher.onSocketClosed()
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    func testLateIdenticalManualResponseCannotReplaceNewOperation() throws {
        let old = try beginManual()
        publisher.endExperience(manualClose: true)
        publisher.mockWaitForQueue()
        let current = try beginManual()
        old.completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        publisher.mockWaitForQueue()
        XCTAssertFalse(old.shouldSend())
        XCTAssertTrue(current.shouldSend())
        XCTAssertFalse(displayDelay.hasAction)
        current.completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testLogoutCancelsPendingRequestAndIgnoresLateReply() throws {
        let request = try beginManual()
        publisher.logout()
        XCTAssertFalse(request.shouldSend())
        request.completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        settle()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertEqual(reloadCount, 0)
    }

    func testScreenChangeCancelsPendingNormalContent() {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        publisher.updateScreen("Next")
        publisher.mockWaitForQueue()
        XCTAssertEqual(publisher.getCurrentScreen, "Next")
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertEqual(reloadCount, 0)
    }

    func testRepeatedOrGeneratedScreensDoNotCancelCurrentContent() {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        publisher.updateScreen("Home")
        publisher.updateScreen(Event(type: .screen("Other"), isFakeReload: true))
        publisher.mockWaitForQueue()
        XCTAssertEqual(publisher.getCurrentScreen, "Home")
        XCTAssertTrue(displayDelay.hasAction)
    }

    func beginManual() throws -> MockAnalyticsPublisher.Request {
        publisher.triggerExperience("flow-a")
        publisher.mockWaitForQueue()
        return try XCTUnwrap(userpilot.analyticsPublisher.requests.last)
    }

    func receiveScreen(_ response: [String: Any], screen: String = "Home") {
        publisher.onSocketEventSent(Constants.Event.screenEvent,
                                    [Constants.Analytics.screenTitleProperty: screen],
                                    Message(payload: response), true)
        publisher.mockWaitForQueue()
    }

    func presentScheduled() throws {
        let shown = expectation(description: "renderer handed to presentation host")
        host.onPresent = { shown.fulfill() }
        try displayDelay.fire()
        wait(for: [shown], timeout: 2)
        host.onPresent = nil
        publisher.mockWaitForQueue()
    }

    /// Drain both ownership boundaries, without advancing the injected display delay or using sleeps.
    func settle() {
        publisher.mockWaitForQueue()
        let drained = expectation(description: "main callbacks processed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        publisher.mockWaitForQueue()
    }
}

final class MockExperiencePresentationHost: UIViewController {
    var presentedExperience: UIViewController?
    var onPresent: (() -> Void)?

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentedExperience = controller
        onPresent?()
        completion?()
    }
}

final class MockExperienceDisplayDelay: DelayUtils {
    private let pendingAction = AtomicReference<(() -> Void)?>(nil)
    var hasAction: Bool { pendingAction.value != nil }

    override func delayAction(delayTime: TimeInterval, action: @escaping () -> Void) {
        pendingAction.value = action
    }

    override func cancelDelay() {
        pendingAction.value = nil
    }

    func fire() throws {
        try XCTUnwrap(pendingAction.getAndSet(nil))()
    }
}
