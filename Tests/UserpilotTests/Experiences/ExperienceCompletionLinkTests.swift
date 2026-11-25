//
//  ExperienceCompletionLinkTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies that completion navigation follows actual removal and respects session cancellation.
//

import XCTest
@testable import Userpilot

extension ExperiencesPublisherTests {
    func testCompletionLinkWaitsForDismissalThen250Milliseconds() throws {
        let renderer = try prepareCompletionLink()
        assertNoCompletionLink()
        let forwarded = expectation(description: "completion link after removal")
        let dismissedAt = ProcessInfo.processInfo.systemUptime
        userpilot.linkOpener.onHandleURL = { [weak self] url in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(url.absoluteString, "https://example.com/next")
            XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - dismissedAt, 0.25)
            XCTAssertNil(self?.publisher.activeRendererID)
            forwarded.fulfill()
        }
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        XCTAssertEqual(reloadCount, 0)
        wait(for: [forwarded], timeout: 2)
    }

    func testDuplicateDismissalOpensCompletionLinkOnlyOnce() throws {
        let renderer = try prepareCompletionLink()
        let forwarded = expectation(description: "one completion link")
        forwarded.assertForOverFulfill = true
        userpilot.linkOpener.onHandleURL = { _ in forwarded.fulfill() }
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        wait(for: [forwarded], timeout: 2)
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        assertNoCompletionLink()
    }

    func testLogoutBeforeDismissalDiscardsCompletionLink() throws {
        let renderer = try prepareCompletionLink()
        publisher.logout()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        assertNoCompletionLink()
        XCTAssertEqual(reloadCount, 0)
    }

    func testLogoutDuringNavigationDelayDiscardsCompletionLink() throws {
        let renderer = try prepareCompletionLink()
        publisher.experienceDidFinishDismissing(rendererID: renderer)
        settle()
        publisher.logout()
        settle()
        assertNoCompletionLink()
    }

    func testScreenChangeDiscardsCompletionLink() throws {
        _ = try prepareCompletionLink()
        publisher.updateScreen("Next")
        settle()
        assertNoCompletionLink()
    }

    func testOldRendererCannotAssignCompletionLinkToReplacement() throws {
        let old = try prepareCompletionLink()
        publisher.endExperience(manualClose: true)
        settle()
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let replacement = try XCTUnwrap(publisher.activeRendererID)
        publisher.setCompletionDeepLink("https://example.com/stale", rendererID: old)
        publisher.experienceDidFinishDismissing(rendererID: replacement)
        settle()
        assertNoCompletionLink()
    }

    func testThankYouLinkWaitsForItsFinalRendererDismissal() throws {
        var response = MockContentFactory.makeSurveyContentPayload()
        var surveyPayload = try XCTUnwrap(response["surveys"] as? [String: Any])
        surveyPayload["type"] = "list"
        surveyPayload["modules"] = [["id": 101, "type": "completed", "metadata": ["enabled": true]]]
        response["surveys"] = surveyPayload
        receiveScreen(response)
        try presentScheduled()
        let original = try XCTUnwrap(publisher.activeRendererID)
        let survey = try XCTUnwrap(publisher.activeExperience?.asSurveyContent())
        publisher.showThankYouMessage(survey, MockContentFactory.makeSurveyTheme(), 10, rendererID: original)
        publisher.mockWaitForQueue()
        try presentScheduled()
        let controller = try XCTUnwrap(host.presentedExperience as? ThankYouBottomSheetViewController)
        controller.actionButtonClicked("https://example.com/thanks")
        publisher.mockWaitForQueue()
        // A late survey callback must not release the thank-you presentation or start navigation.
        publisher.experienceDidFinishDismissing(rendererID: original)
        settle()
        assertNoCompletionLink()
        let forwarded = expectation(description: "thank-you completion link")
        userpilot.linkOpener.onHandleURL = { url in
            XCTAssertEqual(url.absoluteString, "https://example.com/thanks")
            forwarded.fulfill()
        }
        controller.onDismissCompleted()
        settle()
        XCTAssertEqual(reloadCount, 0)
        wait(for: [forwarded], timeout: 2)
    }

    private func prepareCompletionLink() throws -> UUID {
        receiveScreen(MockContentFactory.makeFlowContentPayload())
        try presentScheduled()
        let renderer = try XCTUnwrap(publisher.activeRendererID)
        publisher.setCompletionDeepLink("https://example.com/next", rendererID: renderer)
        publisher.publishInternalSDKEvent(
            FlowExperienceActionEvent.completed(flowId: 77, hasDeepLink: true), rendererID: renderer
        )
        publisher.mockWaitForQueue()
        return renderer
    }

    private func assertNoCompletionLink(file: StaticString = #filePath, line: UInt = #line) {
        let unexpected = expectation(description: "no completion link")
        unexpected.isInverted = true
        userpilot.linkOpener.onHandleURL = { _ in unexpected.fulfill() }
        let result = XCTWaiter.wait(for: [unexpected], timeout: 0.35)
        XCTAssertEqual(result, .completed, file: file, line: line)
    }
}
