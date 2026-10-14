//
//  ExperienceEventPayloadTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 14/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Locks the existing engagement wire contract across the value-event refactor.
//

import XCTest
@testable import Userpilot

final class ExperienceEventPayloadTests: XCTestCase {
    func testFlowPayloadsKeepStepIdsOnlyOnDismissalAndStepEvents() throws {
        try assertEvent(FlowExperienceActionEvent.seen(flowId: 10), "seen_mobile_content", ["mobile_content_id": 10])
        try assertEvent(
            FlowExperienceActionEvent.dismissed(flowId: 10, stepId: 3),
            "dismissed_mobile_content", ["mobile_content_id": 10, "step_id": 3]
        )
        try assertEvent(
            FlowExperienceActionEvent.completed(flowId: 10, hasDeepLink: true),
            "complete_mobile_content", ["mobile_content_id": 10]
        )
        try assertEvent(
            FlowExperienceStepActionEvent.seen(flowId: 10, stepId: 3),
            "seen_mobile_content_step", ["mobile_content_id": 10, "step_id": 3]
        )
        try assertEvent(
            FlowExperienceStepActionEvent.completed(flowId: 10, stepId: 3),
            "completed_mobile_content_step", ["mobile_content_id": 10, "step_id": 3]
        )
    }

    func testSurveyPayloadsPreserveIdentityAndStructuredBatchFeedback() throws {
        let submissionId = Int64.max - 1
        let feedback: [[String: Any]] = [["module_id": 7, "value": ["first", "second"]]]
        try assertEvent(
            SurveyExperienceActionEvent.seen(surveyId: 20, submissionId: submissionId),
            "seen_survey", ["survey_id": 20, "submission_id": submissionId]
        )
        try assertEvent(
            SurveyExperienceActionEvent.dismissed(
                surveyId: 20, submissionId: submissionId, moduleId: 7, type: "multiple_choice"
            ), "dismissed_survey",
            ["survey_id": 20, "submission_id": submissionId, "module_id": 7, "type": "multiple_choice"]
        )
        try assertEvent(
            SurveyExperienceActionEvent.completed(surveyId: 20, submissionId: submissionId, hasDeepLink: true),
            "completed_survey", ["survey_id": 20, "submission_id": submissionId]
        )
        try assertEvent(
            SurveyExperienceActionEvent.submitted(surveyId: 20, submissionId: submissionId, feedback: feedback),
            "completed_survey_module_batch", ["survey_id": 20, "submission_id": submissionId, "feedback": feedback]
        )
    }

    func testSurveyStepPayloadsPreserveModuleTypeAndAnswerShape() throws {
        let events: [(ExperienceEvent, String)] = [
            (SurveyExperienceStepActionEvent.seen(
                surveyId: 20, submissionId: 300, moduleId: 7, type: "open_text"
            ), "seen_survey_module"),
            (SurveyExperienceStepActionEvent.skipped(
                surveyId: 20, submissionId: 300, moduleId: 7, type: "open_text"
            ), "skipped_survey_module"),
            (SurveyExperienceStepActionEvent.submitted(
                surveyId: 20, submissionId: 300, moduleId: 7, type: "open_text"
            ), "completed_survey_module")
        ]
        for (event, name) in events {
            try assertEvent(event, name, [
                "survey_id": 20, "submission_id": Int64(300), "module_id": 7, "type": "open_text"
            ])
            XCTAssertFalse(event.isSeenContentEvent())
            XCTAssertFalse(event.isEventForCloseExperience())
            XCTAssertEqual(event.experience?.type, .survey)
            XCTAssertEqual(event.experience?.id, 20)
        }
        try assertEvent(
            SurveyExperienceStepActionEvent.submitted(
                surveyId: 20, submissionId: 300, moduleId: 7, type: "multiple_choice", feedback: [1, 2]
            ), "completed_survey_module", [
                "survey_id": 20, "submission_id": Int64(300), "module_id": 7,
                "type": "multiple_choice", "feedback": [1, 2]
            ]
        )
    }

    func testNPSPayloadsKeepEmptySeenAndDismissedEvents() throws {
        try assertEvent(NPSExperienceActionEvent.seen, "seen_NPS", [:])
        try assertEvent(NPSExperienceActionEvent.dismissed, "dismiss_NPS", [:])
        try assertEvent(
            NPSExperienceActionEvent.submitted(
                score: 9, npsKey: "score-key", feedback: "great", feedbackKey: "follow-up"
            ),
            "NPS_feedback", [
                "score": 9, "survey_question_key": "score-key", "feedback": "great",
                "follow_up_question_key": "follow-up"
            ]
        )
    }

    func testOptionalFieldsPreserveOmittedEmptyAndExplicitNullValues() throws {
        try assertEvent(
            SurveyExperienceActionEvent.dismissed(surveyId: 20, submissionId: 300, moduleId: nil, type: nil),
            "dismissed_survey", ["survey_id": 20, "submission_id": Int64(300)]
        )
        try assertEvent(
            SurveyExperienceActionEvent.dismissed(surveyId: 20, submissionId: 300, moduleId: 0, type: ""),
            "dismissed_survey", ["survey_id": 20, "submission_id": Int64(300), "module_id": 0, "type": ""]
        )
        for feedback: Any? in [nil, "", NSNull()] {
            var surveyPayload: [String: Any] = ["survey_id": 20, "submission_id": Int64(300)]
            var npsPayload: [String: Any] = [
                "score": 0, "survey_question_key": "score", "follow_up_question_key": "follow-up"
            ]
            surveyPayload["feedback"] = feedback
            npsPayload["feedback"] = feedback
            try assertEvent(
                SurveyExperienceActionEvent.submitted(surveyId: 20, submissionId: 300, feedback: feedback),
                "completed_survey_module_batch", surveyPayload
            )
            try assertEvent(
                NPSExperienceActionEvent.submitted(
                    score: 0, npsKey: "score", feedback: feedback, feedbackKey: "follow-up"
                ),
                "NPS_feedback", npsPayload
            )
        }
    }

    func testLifecycleMetadataIsPreservedThroughExperienceEventContract() {
        let completed: ExperienceEvent = FlowExperienceActionEvent.completed(flowId: 10, hasDeepLink: true)
        XCTAssertTrue(completed.hasDeepLink)
        XCTAssertTrue(completed.isEventForCloseExperience())
        XCTAssertEqual(completed.experience?.type, .flow)
        XCTAssertEqual(completed.experience?.id, 10)
        let survey: ExperienceEvent = SurveyExperienceActionEvent.completed(
            surveyId: 20, submissionId: 300, hasDeepLink: true
        )
        XCTAssertTrue(survey.hasDeepLink)
        XCTAssertTrue(survey.isEventForCloseExperience())
        let step: ExperienceEvent = FlowExperienceStepActionEvent.completed(flowId: 10, stepId: 3)
        XCTAssertFalse(step.isEventForCloseExperience())
        XCTAssertFalse(step.isSeenContentEvent())
        XCTAssertEqual(step.experience?.type, .flow)
        for nps: ExperienceEvent in [
            NPSExperienceActionEvent.dismissed,
            NPSExperienceActionEvent.submitted(score: 9, npsKey: "score", feedback: nil, feedbackKey: "follow-up")
        ] {
            XCTAssertNil(nps.experience)
            XCTAssertFalse(nps.isSeenContentEvent())
            XCTAssertFalse(nps.isEventForCloseExperience())
            XCTAssertTrue(nps.isEventForCloseNPSExperience())
        }
    }

    private func assertEvent(
        _ event: SDKEvent, _ name: String, _ payload: [String: Any],
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        XCTAssertEqual(event.eventName, name, file: file, line: line)
        XCTAssertEqual(
            try JSONSerialization.data(withJSONObject: event.eventPayload, options: .sortedKeys),
            try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
            name, file: file, line: line
        )
        XCTAssertTrue(event.isOfflineEligible, file: file, line: line)
    }
}
