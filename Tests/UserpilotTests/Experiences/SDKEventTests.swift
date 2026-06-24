//
//  SDKEventTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class SDKEventTests: XCTestCase {

    func testSDKEventCloseHelpersAndContentMetadata() {
        let flowSeen = ExperienceFlowSeenEvent(flowId: 11)
        let flowDismissed = ExperienceFlowDismissedEvent(flowId: 11, stepId: 4)
        let surveySeen = ExperienceSurveySeenEvent(surveyId: 22, submissionId: 100)
        let npsDismissed = ExperienceNPSDismissedEvent()

        XCTAssertTrue(flowDismissed.isEventForCloseExperience())
        XCTAssertFalse(flowSeen.isEventForCloseExperience())
        XCTAssertTrue(npsDismissed.isEventForCloseNPSExperience())
        XCTAssertEqual(flowSeen.getContentType(), .flow)
        XCTAssertEqual(flowSeen.getContentId(), 11)
        XCTAssertEqual(surveySeen.getContentType(), .survey)
        XCTAssertEqual(surveySeen.getContentId(), 22)
        XCTAssertTrue(flowSeen.isSeenContentEvent())
        XCTAssertTrue(surveySeen.isSeenContentEvent())
    }

    func testFlowEventsExposeExpectedNamesPayloadsAndDeepLinkFlags() {
        let seen = ExperienceFlowSeenEvent(flowId: 10)
        let dismissed = ExperienceFlowDismissedEvent(flowId: 10, stepId: 3)
        let completed = ExperienceFlowCompletedEvent(flowId: 10, hasDeepLinkContent: true)
        let stepSeen = ExperienceFlowStepSeenEvent(flowId: 10, stepId: 2)
        let stepCompleted = ExperienceFlowStepCompletedEvent(flowId: 10, stepId: 2)

        XCTAssertEqual(seen.eventName, SDKEventsName.flowExperienceSeen.rawValue)
        XCTAssertEqual(seen.eventPayload["mobile_content_id"] as? Int, 10)
        XCTAssertEqual(dismissed.eventName, SDKEventsName.flowExperienceDismissed.rawValue)
        XCTAssertEqual(dismissed.eventPayload["step_id"] as? Int, 3)
        XCTAssertEqual(completed.eventName, SDKEventsName.flowExperienceCompleted.rawValue)
        XCTAssertTrue(completed.hasDeepLink)
        XCTAssertEqual(stepSeen.eventName, SDKEventsName.flowExperienceStepSeen.rawValue)
        XCTAssertEqual(stepSeen.eventPayload["step_id"] as? Int, 2)
        XCTAssertEqual(stepCompleted.eventName, SDKEventsName.flowExperienceStepCompleted.rawValue)
    }

    func testSurveyEventsExposeExpectedNamesPayloadsAndDeepLinkFlags() {
        let seen = ExperienceSurveySeenEvent(surveyId: 20, submissionId: 300)
        let dismissed = ExperienceSurveyDismissedEvent(
            surveyId: 20,
            submissionId: 300,
            moduleId: 5,
            type: "open_text"
        )
        let completed = ExperienceSurveyCompletedEvent(
            surveyId: 20,
            submissionId: 300,
            hasDeepLinkContent: true
        )
        let submitted = ExperienceSurveySubmittedEvent(
            surveyId: 20,
            submissionId: 300,
            feedback: [["value": "ok"]]
        )
        let stepSeen = ExperienceSurveyStepSeenEvent(
            surveyId: 20,
            submissionId: 300,
            moduleId: 5,
            type: "open_text"
        )
        let stepSkipped = ExperienceSurveyStepSkippedEvent(
            surveyId: 20,
            submissionId: 300,
            moduleId: 5,
            type: "open_text"
        )
        let stepSubmitted = ExperienceSurveyStepSubmittedEvent(
            surveyId: 20,
            submissionId: 300,
            moduleId: 5,
            type: "open_text",
            feedback: "answer"
        )

        XCTAssertEqual(seen.eventName, SDKEventsName.surveyExperienceSeen.rawValue)
        XCTAssertEqual(seen.eventPayload["survey_id"] as? Int, 20)
        XCTAssertEqual(seen.eventPayload["submission_id"] as? Int64, 300)
        XCTAssertEqual(dismissed.eventPayload["module_id"] as? Int, 5)
        XCTAssertEqual(dismissed.eventPayload["type"] as? String, "open_text")
        XCTAssertTrue(completed.hasDeepLink)
        XCTAssertEqual(submitted.eventName, SDKEventsName.surveyExperienceSubmitted.rawValue)
        XCTAssertNotNil(submitted.eventPayload["feedback"])
        XCTAssertEqual(stepSeen.eventName, SDKEventsName.surveyExperienceStepSeen.rawValue)
        XCTAssertEqual(stepSkipped.eventName, SDKEventsName.surveyExperienceStepSkipped.rawValue)
        XCTAssertEqual(stepSubmitted.eventName, SDKEventsName.surveyExperienceStepSubmitted.rawValue)
        XCTAssertEqual(stepSubmitted.eventPayload["feedback"] as? String, "answer")
    }

    func testNPSEventsExposeExpectedNamesAndPayloads() {
        let seen = ExperienceNPSSeenEvent()
        let dismissed = ExperienceNPSDismissedEvent()
        let submitted = ExperienceNPSSubmittedEvent(
            score: 9,
            npsKey: "score-key",
            feedback: "great",
            feedbackKey: "feedback-key"
        )

        XCTAssertEqual(seen.eventName, SDKEventsName.npsExperienceSeen.rawValue)
        XCTAssertTrue(seen.eventPayload.isEmpty)
        XCTAssertEqual(dismissed.eventName, SDKEventsName.npsExperienceDismissed.rawValue)
        XCTAssertEqual(submitted.eventName, SDKEventsName.npsExperienceSubmitted.rawValue)
        XCTAssertEqual(submitted.eventPayload["score"] as? Int, 9)
        XCTAssertEqual(submitted.eventPayload["survey_question_key"] as? String, "score-key")
        XCTAssertEqual(submitted.eventPayload["feedback"] as? String, "great")
        XCTAssertEqual(submitted.eventPayload["follow_up_question_key"] as? String, "feedback-key")
    }

    func testFetchAndPushEventsExposeExpectedPayloads() {
        let theme = ThemeContentEvent(themeId: 7, token: "app-token")
        let content = ExperienceContentEvent(experienceId: "mobile:1")
        let pushToken = PushNotificationTokenEvent(appToken: "app-token", userId: "user-1", token: "device-token")
        let opened = PushNotificationOpenedEvent(payload: ["notification_id": "n1"])
        let logout = UserLogoutEvent(appToken: "app-token", userId: "user-1", token: "device-token")

        XCTAssertEqual(theme.eventName, SDKEventsName.fetchExperienceTheme.rawValue)
        XCTAssertEqual(theme.eventPayload["theme_id"] as? Int, 7)
        XCTAssertEqual(theme.eventPayload["app_token"] as? String, "app-token")
        XCTAssertEqual(content.eventName, SDKEventsName.fetchExperienceContent.rawValue)
        XCTAssertEqual(content.eventPayload["mobile_content_token"] as? String, "mobile:1")
        XCTAssertEqual(pushToken.eventName, SDKEventsName.pushNotificationToken.rawValue)
        XCTAssertEqual(pushToken.eventPayload["token"] as? String, "device-token")
        XCTAssertEqual(opened.eventName, SDKEventsName.pushNotificationOpened.rawValue)
        XCTAssertEqual(opened.eventPayload["notification_id"] as? String, "n1")
        XCTAssertEqual(logout.eventName, SDKEventsName.userLogout.rawValue)
        XCTAssertEqual(logout.eventPayload["user_id"] as? String, "user-1")
    }
}
