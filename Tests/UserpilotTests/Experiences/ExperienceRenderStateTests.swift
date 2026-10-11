//
//  ExperienceRenderStateTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies render-state event identity, native teardown and retained form values.
//

import UIKit
import XCTest

@testable import Userpilot

final class ExperienceRenderStateTests: XCTestCase {
    private var userpilot: MockUserpilot!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(config: Userpilot.Config(token: "RENDER-\(UUID().uuidString)").defaultInstance(false))
        userpilot.themeHandler.onMergeExperienceThemes = { _, theme, _ in
            ThemeData(carousel: theme ?? ExperienceTheme(), slideOut: theme ?? ExperienceTheme(), survey: nil)
        }
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
    }

    override func tearDown() {
        userpilot = nil
        super.tearDown()
    }

    func testRepeatedStartAppearanceAndRedrawReportSeenOnlyOnce() throws {
        let content = try flow()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: content) }
        let state = ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container)))
        let seen = expectation(description: "flow and initial step seen")
        seen.expectedFulfillmentCount = 2
        seen.assertForOverFulfill = true
        var events: [String] = []
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { event in
            events.append(event.eventName)
            seen.fulfill()
        }
        state.start()
        state.start()
        state.appeared()
        state.refresh()
        state.appeared()
        wait(for: [seen], timeout: 2)
        XCTAssertEqual(
            events,
            [
                SDKEventsName.flowExperienceSeen.rawValue,
                SDKEventsName.flowExperienceStepSeen.rawValue
            ])
    }

    func testRepeatedCloseWaitsForNativeCompletionAndOnlyReportsOnce() throws {
        let content = try flow()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: content) }
        let state = ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container)))
        var nativeCompletion: (() -> Void)?
        var dismissalCount = 0
        var eventCount = 0
        state.dismiss = { nativeCompletion = $0 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { dismissalCount += 1 }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { _ in eventCount += 1 }
        state.start()
        state.userClose()
        state.userClose()
        XCTAssertEqual(eventCount, 1)
        XCTAssertEqual(dismissalCount, 0)
        try XCTUnwrap(nativeCompletion)()
        XCTAssertEqual(dismissalCount, 1)
    }

    func testSurveyAnswerSurvivesRootRecreationAndSubmitsExistingPayload() throws {
        let survey = MockContentFactory.makeSurveyContent()
        let step = try XCTUnwrap(survey.modules.first)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let state = ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container)))
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        state.start()
        state.updateAnswer(for: step) { $0.rating = 4 }
        _ = UPExperienceRootView(state: state, width: 390)
        _ = UPExperienceRootView(state: state, width: 844)
        state.refresh()
        XCTAssertEqual(state.answer(for: step).rating, 4)
        state.submitSurvey()
        XCTAssertEqual(events.first?.eventName, SDKEventsName.surveyExperienceStepSubmitted.rawValue)
        XCTAssertEqual(state.answer(for: step).payload(for: step)?["value"] as? Int, 4)
    }

    func testListThankYouContinuationStartsOnlyAfterNativeDismissal() throws {
        var payload = MockContentFactory.makeSurveyContentPayload()
        var body = try XCTUnwrap(payload["surveys"] as? [String: Any])
        body["type"] = "list"
        body["modules"] = [
            ["id": 1, "type": "open_text", "is_required": false],
            ["id": 2, "type": "completed", "metadata": ["enabled": true]]
        ]
        payload["surveys"] = body
        let survey = try XCTUnwrap(payload.toJSONString()?.toSurveyContent()?.surveyContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        var handoffs = 0
        var finished = 0
        var completion: (() -> Void)?
        userpilot.experiencesPublisher.onHasNextFlowStep = { true }
        userpilot.experiencesPublisher.onShowThankYouMessage = { _, _, _ in handoffs += 1 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { finished += 1 }
        let state = ExperienceRenderState(.survey(SurveyViewModel(container: userpilot.container)))
        state.dismiss = { completion = $0 }
        state.start()
        state.submitSurvey()
        XCTAssertEqual(handoffs, 0)
        XCTAssertEqual(finished, 0)
        try XCTUnwrap(completion)()
        XCTAssertEqual(handoffs, 1)
        XCTAssertEqual(finished, 0)
    }

    func testNPSBucketBoundariesAndPublishedScoreUseDisplayedZeroBasedScore() throws {
        let nps = try scoreBasedNPS()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        var published: [SDKEvent] = []
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { published.append($0) }
        for (score, key) in [
            (0, "detractors"), (6, "detractors"), (7, "passives"),
            (8, "passives"), (9, "promoters"), (10, "promoters")
        ] {
            let state = ExperienceRenderState(.nps(NPSViewModel(container: userpilot.container)))
            state.start()
            state.selectNPSScore(score + 1)
            XCTAssertEqual(state.followUp?.key, key)
            XCTAssertEqual(state.completedData?.header, key)
            state.submitNPS()
            state.submitNPS()
            XCTAssertEqual(published.last?.eventPayload["score"] as? Int, score)
            XCTAssertEqual(published.last?.eventPayload["follow_up_question_key"] as? String, key)
        }
        XCTAssertEqual(published.count, 6)
    }

    func testSlideoutCompletionEventPrecedesReleaseButFollowsNativeRemoval() throws {
        let original = try flow()
        let slideout = FlowContent(id: original.id, type: .slideout, steps: original.steps,
                                   mobileTheme: original.mobileTheme, screens: [], screenType: .all, localeCode: "en")
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: slideout) }
        let state = ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container)))
        var nativeCompletion: (() -> Void)?
        var calls: [String] = []
        state.dismiss = { nativeCompletion = $0 }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { calls.append($0.eventName) }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { calls.append("removed") }
        state.start()
        state.flowAction()
        XCTAssertTrue(calls.isEmpty)
        try XCTUnwrap(nativeCompletion)()
        XCTAssertEqual(calls, [SDKEventsName.flowExperienceStepCompleted.rawValue,
                               SDKEventsName.flowExperienceCompleted.rawValue, "removed"])
    }

    func testNPSCloseSubmitsScoreButDoesNotSubmitUnsentFeedback() throws {
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        let state = ExperienceRenderState(.nps(NPSViewModel(container: userpilot.container)))
        state.start()
        state.selectNPSScore(8)
        state.npsFeedback = "Draft feedback"
        state.userClose()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventPayload["score"] as? Int, 7)
        XCTAssertEqual(events.first?.eventPayload["feedback"] as? String, "")
        XCTAssertEqual(events.first?.eventPayload["follow_up_question_key"] as? String, "nps_followup")
    }

    private func flow() throws -> FlowContent {
        try XCTUnwrap(MockContentFactory.makeFlowContentPayload().toJSONString()?.toFlowContent()?.flowContent)
    }

    private func scoreBasedNPS() throws -> NPSContent {
        var payload = MockContentFactory.makeNPSContentPayload()
        var nps = try XCTUnwrap(payload["nps"] as? [String: Any])
        var content = try XCTUnwrap(nps["content"] as? [String: Any])
        var followUp: [String: Any] = ["type": "score_based"]
        var completed: [String: Any] = ["type": "score_based"]
        for key in ["detractors", "passives", "promoters"] {
            followUp[key] = ["key": key, "question": key]
            completed[key] = ["header": key, "button": ["enabled": true]]
        }
        content["follow_up"] = followUp
        content["completed"] = completed
        nps["content"] = content
        payload["nps"] = nps
        return try XCTUnwrap(payload.toJSONString()?.toNPSContent()?.npsContent)
    }
}
