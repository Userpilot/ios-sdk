//
//  ExperiencesPublisherLifecycleTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Exercises presentation identity, final dismissal, preview replacement and per-screen NPS policy.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    func testContentReadsKeepCurrentContentUntilDismissal() throws {
        let renderer = try presentFlow()
        XCTAssertEqual(publisher.getActiveMobileContent(rendererID: renderer)?.experienceId(), 77)
        XCTAssertEqual(publisher.getActiveMobileContent(rendererID: renderer)?.experienceId(), 77)
        XCTAssertNil(publisher.getActiveMobileContent(rendererID: UUID()))
        XCTAssertNil(publisher.getActiveMobileContent(rendererID: nil))
    }

    func testCloseEventWaitsForFinalDismissalBeforeRequestingReload() throws {
        let renderer = try presentFlow()
        sendClose(renderer)
        XCTAssertEqual(reloadCount, 0)
        XCTAssertFalse(publisher.canRequestScreenEvent())
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 1)
        XCTAssertNil(publisher.activeRendererID)
    }

    func testDuplicateDismissalCannotRequestSecondReload() throws {
        let renderer = try presentFlow()
        sendClose(renderer)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 1)
    }

    func testUncorrelatedCallbacksCannotReleaseOrPublishForCurrentRenderer() throws {
        let renderer = try presentFlow()
        publishedEvents.removeAll()
        publisher.publishInternalSDKEvent(MockSDKEvent())
        publisher.publishInternalSDKEvent(MockSDKEvent(), rendererID: UUID())
        publisher.experienceDidFinishDismissing()
        publisher.experienceDidFinishDismissing(rendererID: UUID())
        settle()
        XCTAssertEqual(publisher.activeRendererID, renderer)
        XCTAssertTrue(publishedEvents.isEmpty)
    }

    func testMatchingRendererForwardsAnalytics() throws {
        let renderer = try presentFlow()
        publishedEvents.removeAll()
        publisher.publishInternalSDKEvent(MockSDKEvent(eventName: "test-event"), rendererID: renderer)
        publisher.mockWaitForQueue()
        XCTAssertEqual(publishedEvents.map(\.eventName), ["test-event"])
    }

    func testDeepLinkCloseDoesNotRequestReload() throws {
        let renderer = try presentFlow()
        sendClose(renderer, hasDeepLink: true)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 0)
    }

    func testNPSCloseDoesNotRequestReload() throws {
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        try presentScheduled()
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        let close = MockSDKEvent(eventName: "dismiss_nps")
        close.isCloseNPSEvent = true
        publisher.publishInternalSDKEvent(close, rendererID: renderer)
        publisher.mockWaitForQueue()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 0)
    }

    func testOfflineCloseStillRequestsQueuedReloadAfterDismissal() throws {
        let renderer = try presentFlow()
        userpilot.analyticsPublisher.canRequestEvent = false
        sendClose(renderer)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 1)
    }

    func testFinalDismissalWithoutCloseEventDoesNotInventReload() throws {
        let renderer = try presentFlow()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 0)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testLogoutInvalidatesRendererImmediatelyAndSkipsReload() throws {
        let renderer = try presentFlow()
        sendClose(renderer)
        publishedEvents.removeAll()
        publisher.logout()
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertNil(publisher.getActiveMobileContent(rendererID: renderer))
        publisher.publishInternalSDKEvent(MockSDKEvent(), rendererID: renderer)
        settle()
        XCTAssertTrue(publishedEvents.isEmpty)
        XCTAssertEqual(reloadCount, 0)
    }

    func testScreenNavigationDismissesContentWithoutReload() throws {
        _ = try presentFlow()
        publisher.updateScreen("Next")
        settle()
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertEqual(reloadCount, 0)
    }

    func testOldRendererCannotDismissReplacement() throws {
        let old = try presentFlow()
        publisher.experienceDidFinishDismissing(rendererID: old)
        settle()
        let current = try presentFlow()
        XCTAssertNotEqual(old, current)
        publisher.experienceDidFinishDismissing(rendererID: old)
        publisher.publishInternalSDKEvent(MockSDKEvent(), rendererID: old)
        settle()
        XCTAssertEqual(publisher.activeRendererID, current)
    }

    func testNPSIsSuppressedAfterPresentationOnSameScreen() throws {
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        try presentScheduled()
        publisher.experienceDidFinishDismissing(rendererID: publisher.activeRendererID)
        settle()
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        XCTAssertFalse(displayDelay.hasAction)
        XCTAssertNil(publisher.activeRendererID)
    }

    func testNPSBecomesEligibleOnNewScreenVisit() throws {
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        try presentScheduled()
        publisher.experienceDidFinishDismissing(rendererID: publisher.activeRendererID)
        settle()
        publisher.updateScreen("Next")
        publisher.mockWaitForQueue()
        publisher.updateScreen("Home")
        publisher.mockWaitForQueue()
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testLogoutResetsNPSSuppression() throws {
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        try presentScheduled()
        publisher.logout()
        settle()
        receiveScreen(MockContentFactory.makeNPSContentPayload())
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testPreviewFetchOwnsAdmissionAndUsesQueryContentType() throws {
        var fetched: PreviewExperienceQueryParams?
        userpilot.remoteSource.onFetchPreviewExperience = { params, _ in fetched = params }
        publisher.triggerPreviewExperience("preview-a", [URLQueryItem(name: "type", value: "flow")])
        publisher.mockWaitForQueue()
        XCTAssertEqual(try XCTUnwrap(fetched).contentId, "preview-a")
        XCTAssertEqual(fetched?.contentType, "flow")
        XCTAssertFalse(publisher.canRequestScreenEvent())
        publisher.triggerExperience("ignored-manual")
        publisher.mockWaitForQueue()
        XCTAssertTrue(userpilot.analyticsPublisher.requests.isEmpty)
    }

    func testPreviewReplacesPendingManualRequestAndInvalidatesItsReply() throws {
        let old = try beginManual()
        var fetched = false
        userpilot.remoteSource.onFetchPreviewExperience = { _, _ in fetched = true }
        publisher.triggerPreviewExperience("preview-a", [])
        publisher.mockWaitForQueue()
        XCTAssertTrue(fetched)
        XCTAssertFalse(old.shouldSend())
        old.completion?(Message(payload: MockContentFactory.makeFlowContentPayload()), true)
        publisher.mockWaitForQueue()
        XCTAssertFalse(displayDelay.hasAction)
    }

    func testNewerPreviewRejectsOldFetchCompletion() throws {
        var callbacks: [(Result<PreviewExperience, RemoteSourceError>) -> Void] = []
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in callbacks.append(completion) }
        publisher.triggerPreviewExperience("preview-a", [])
        publisher.mockWaitForQueue()
        publisher.triggerPreviewExperience("preview-b", [])
        publisher.mockWaitForQueue()
        XCTAssertEqual(callbacks.count, 2)
        callbacks[0](.success(try makePreview()))
        publisher.mockWaitForQueue()
        XCTAssertFalse(displayDelay.hasAction)
        callbacks[1](.success(try makePreview()))
        publisher.mockWaitForQueue()
        XCTAssertTrue(displayDelay.hasAction)
    }

    func testScreenChangeAndSocketClosePreservePendingPreview() {
        userpilot.remoteSource.onFetchPreviewExperience = { _, _ in }
        publisher.triggerPreviewExperience("preview-a", [])
        publisher.mockWaitForQueue()
        publisher.updateScreen("Next")
        publisher.onSocketClosed()
        publisher.mockWaitForQueue()
        XCTAssertFalse(publisher.canRequestScreenEvent())
    }

    func testPreviewUsesBundledThemeAndSuppressesRendererAnalytics() throws {
        let renderer = try presentPreview()
        XCTAssertTrue(userpilot.analyticsPublisher.requests.isEmpty)
        publishedEvents.removeAll()
        publisher.publishInternalSDKEvent(MockSDKEvent(), rendererID: renderer)
        publisher.mockWaitForQueue()
        XCTAssertTrue(publishedEvents.isEmpty)
    }

    func testPreviewFlowCloseReloadsOnlyAfterFinalDismissal() throws {
        let renderer = try presentPreview()
        sendClose(renderer)
        XCTAssertEqual(reloadCount, 0)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 1)
    }

    func testPreviewDismissalDoesNotReplayDroppedManualRequest() throws {
        let renderer = try presentPreview()
        publisher.triggerExperience("ignored-manual")
        publisher.mockWaitForQueue()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertTrue(userpilot.analyticsPublisher.requests.isEmpty)
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testInvalidPreviewResponseReleasesAdmission() {
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in
            completion(.success(PreviewExperience(flow: nil, survey: nil, contentType: "flow", theme: nil)))
        }
        publisher.triggerPreviewExperience("preview-a", [])
        settle()
        XCTAssertTrue(publisher.canRequestScreenEvent())
    }

    func testPresentationWithoutHostReleasesAdmission() throws {
        publisher.topViewControllerProvider = { nil }
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try displayDelay.fire()
        settle()
        XCTAssertTrue(publisher.canRequestScreenEvent())
        XCTAssertNil(publisher.activeRendererID)
    }

    func testSurveyThankYouRetainsOperationAndRejectsOldRendererCallbacks() throws {
        var response = MockContentFactory.makeSurveyContentPayload()
        var surveyPayload = try XCTUnwrap(response["surveys"] as? [String: Any])
        surveyPayload["type"] = "list"
        surveyPayload["modules"] = [["id": 101, "type": "completed", "metadata": ["enabled": true]]]
        response["surveys"] = surveyPayload
        receiveScreen(response)
        try presentScheduled()
        let original = try XCTUnwrap(publisher.activeRendererID)
        let survey = try XCTUnwrap(publisher.getActiveMobileContent()?.asSurveyContent())
        XCTAssertTrue(publisher.hasNextFlowStep(rendererID: original))
        publisher.showThankYouMessage(survey, MockContentFactory.makeSurveyTheme(), 10, rendererID: original)
        publisher.mockWaitForQueue()
        XCTAssertNil(publisher.activeRendererID)
        XCTAssertFalse(publisher.canRequestScreenEvent())
        try presentScheduled()
        let thankYou = try XCTUnwrap(publisher.activeRendererID)
        XCTAssertNotEqual(original, thankYou)
        publisher.experienceDidFinishDismissing(rendererID: original)
        settle()
        XCTAssertEqual(publisher.activeRendererID, thankYou)
        let controller = try XCTUnwrap(host.presentedExperience as? ThankYouBottomSheetViewController)
        controller.onDismissCompleted()
        settle()
        XCTAssertNil(publisher.activeRendererID)
    }

    private func presentFlow() throws -> UUID {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        return try XCTUnwrap(publisher.activeRendererID)
    }

    private func sendClose(_ renderer: UUID, hasDeepLink: Bool = false) {
        let close = MockSDKEvent(eventName: "dismissed_mobile_content", hasDeepLink: hasDeepLink)
        close.isCloseEvent = true
        publisher.publishInternalSDKEvent(close, rendererID: renderer)
        publisher.mockWaitForQueue()
    }

    private func presentPreview() throws -> UUID {
        let preview = try makePreview()
        userpilot.remoteSource.onFetchPreviewExperience = { _, completion in completion(.success(preview)) }
        publisher.triggerPreviewExperience("preview-a", [])
        publisher.mockWaitForQueue()
        publisher.mockWaitForQueue()
        try presentScheduled()
        return try XCTUnwrap(publisher.activeRendererID)
    }

    private func makePreview() throws -> PreviewExperience {
        let flow = try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent
        )
        let theme = ThemeContent(id: 1, themeData: ThemeData(carousel: nil, slideOut: nil, survey: nil))
        return PreviewExperience(flow: flow, survey: nil, contentType: "flow", theme: theme)
    }
}
