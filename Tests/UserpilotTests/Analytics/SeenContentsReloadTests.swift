//
//  SeenContentsReloadTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The fake reload after a dismissal carries no content: content is recorded as seen when it shows,
//  so the reload's `seen_contents` and `seen_surveys` still name it. Runs the real analytics and
//  experience owners with controlled acknowledgments and presentation scheduling.
//

import XCTest
@testable import Userpilot

final class SeenContentsReloadTests: XCTestCase {
    private var owner: MockUserpilot!
    private var analytics: AnalyticsPublisher!
    private var experiences: ExperiencesPublisher!
    private var delay: MockExperienceDisplayDelay!
    private var host: MockExperiencePresentationHost!

    override func setUp() {
        super.setUp()
        owner = MockUserpilot.make(config: Userpilot.Config(token: "SEEN-\(UUID().uuidString)").defaultInstance(false))
        owner.container.owner = nil
        owner.socketManager.isSocketOpened = true
        owner.themeHandler.onGetThemeById = { _ in ThemeData(carousel: nil, slideOut: nil, survey: nil) }
        analytics = AnalyticsPublisher(container: owner.container)
        owner.container.register(AnalyticsPublishing.self, value: analytics!)
        experiences = ExperiencesPublisher(container: owner.container)
        owner.container.register(ExperiencesPublishing.self, value: experiences!)
        delay = MockExperienceDisplayDelay()
        experiences.mockSetDelayUtils(delay)
        host = MockExperiencePresentationHost()
        experiences.topViewControllerProvider = { [weak self] in self?.host }
    }

    override func tearDown() {
        experiences?.logout()
        experiences?.mockWaitForQueue()
        analytics = nil
        experiences = nil
        owner = nil
        delay = nil
        host = nil
        super.tearDown()
    }

    func testStandaloneContentsDismissalReload_namesItInSeenContents() throws {
        let renderer = try show(MockContentFactory.makeFlowContentPayload())
        experiences.publishInternalSDKEvent(FlowExperienceActionEvent.dismissed(flowId: 77, stepId: 114),
                                            rendererID: renderer)

        let reload = try reloadAfterRemoving(renderer)

        XCTAssertEqual(reload[Constants.Analytics.fakeReload] as? Bool, true)
        XCTAssertEqual(reload[Constants.Analytics.seenContents] as? [Int], [77])
        XCTAssertEqual(reload[Constants.Analytics.seenSurveys] as? [Int], [])
    }

    func testAFlowWalksReload_namesTheFlowAndItsShownStepInSeenContents() throws {
        let renderer = try show(TooltipFixture.flowPayload(types: ["modal"]))
        let experience = try XCTUnwrap(experiences.getActiveExperience(rendererID: renderer))
        var segment = try XCTUnwrap(experience.flowSegment())
        let step = try XCTUnwrap(experience.asFlowContent()?.steps.first)
        let shown = FlowStepEvents.shown(segment, step)
        segment.run = shown.run
        experiences.publishFlowStepOutcome(shown, rendererID: renderer)
        experiences.publishFlowStepOutcome(FlowStepEvents.advanced(segment, step), rendererID: renderer)

        let reload = try reloadAfterRemoving(renderer)

        XCTAssertEqual(reload[Constants.Analytics.fakeReload] as? Bool, true)
        XCTAssertEqual(Set(reload[Constants.Analytics.seenContents] as? [Int] ?? []), [40, 401])
        XCTAssertEqual(reload[Constants.Analytics.seenSurveys] as? [Int], [])
    }

    func testASurveysDismissalReload_namesItInSeenSurveys() throws {
        let renderer = try show(MockContentFactory.makeSurveyContentPayload())
        let close = SurveyExperienceActionEvent.dismissed(surveyId: 12, submissionId: 1, moduleId: 101, type: "step")
        experiences.publishInternalSDKEvent(close, rendererID: renderer)

        let reload = try reloadAfterRemoving(renderer)

        XCTAssertEqual(reload[Constants.Analytics.fakeReload] as? Bool, true)
        XCTAssertEqual(reload[Constants.Analytics.seenSurveys] as? [Int], [12])
        XCTAssertEqual(reload[Constants.Analytics.seenContents] as? [Int], [])
    }

    // MARK: - Helpers

    /// Sends `Home`, answers it with `response` and presents the content, returning its renderer.
    private func show(_ response: [String: Any]) throws -> UUID {
        analytics.testPublish(Event(type: .screen("Home")))
        experiences.mockWaitForQueue()
        let screen = try XCTUnwrap(owner.socketManager.requests.first { $0.event == Constants.Event.screenEvent })
        let reply = Message(payload: response)
        owner.socketManager.completeNext(Constants.Event.screenEvent, nil, reply, true)
        analytics.testSettle()
        // The socket hands the reply to its subscribers after the sender's own completion.
        experiences.onSocketEventSent(Constants.Event.screenEvent, screen.payload, reply, true)
        experiences.mockWaitForQueue()
        let presented = expectation(description: "renderer handed to presentation host")
        host.onPresent = { presented.fulfill() }
        try delay.fire()
        wait(for: [presented], timeout: 2)
        host.onPresent = nil
        experiences.mockWaitForQueue()
        return try XCTUnwrap(experiences.activeRendererID)
    }

    /// Removes the renderer and returns the metadata of the screen message the dismissal sent.
    private func reloadAfterRemoving(_ renderer: UUID) throws -> [String: Any] {
        experiences.mockWaitForQueue()
        experiences.experienceDidFinishDismissing(rendererID: renderer)
        let drained = expectation(description: "main callbacks processed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        experiences.mockWaitForQueue()
        analytics.testSettle()
        let reload = try XCTUnwrap(owner.socketManager.requests.last { $0.event == Constants.Event.screenEvent })
        return try XCTUnwrap(reload.payload?[Constants.Analytics.metaDataProperty] as? [String: Any])
    }
}
