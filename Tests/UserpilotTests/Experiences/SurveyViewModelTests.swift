//
//  SurveyViewModelTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class SurveyViewModelTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var viewModel: SurveyViewModel!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(
            config: Userpilot.Config(token: "SURVEY-VM-\(UUID().uuidString)").defaultInstance(false)
        )
        userpilot.themeHandler.onMergeSurveyThemes = { _, surveyTheme in
            surveyTheme ?? MockContentFactory.makeSurveyTheme()
        }
        viewModel = SurveyViewModel(container: userpilot.container)
    }

    override func tearDown() {
        viewModel = nil
        userpilot = nil
        super.tearDown()
    }

    func testOnStartBindsFalseWhenNoSurveyContentExists() {
        var didBind: Bool?
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, false)
    }

    func testOnStartBindsSurveyAndRemovesDisabledCompletedModule() {
        let survey = Self.makeSurveyContent(modules: [
            Self.makeStep(id: 1, required: true),
            Self.makeCompletedStep(id: 2, enabled: false)
        ])
        var didBind: Bool?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, true)
        XCTAssertEqual(viewModel.surveyContent?.modules.count, 1)
        XCTAssertTrue(viewModel.isAnyQuestionRequired())
        XCTAssertFalse(viewModel.isRTL)
    }

    func testOnStartBindsFalseWhenSurveyHasNoModules() {
        let survey = Self.makeSurveyContent(modules: [])
        var didBind: Bool?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, false)
    }

    func testShowThankYouMessageDelegatesWhenCompletedModuleExists() {
        let survey = Self.makeSurveyContent(modules: [
            Self.makeStep(id: 1),
            Self.makeCompletedStep(id: 2, enabled: true)
        ])
        var shownSurveyId: Int?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onShowThankYouMessage = { survey, _, _ in
            shownSurveyId = survey.id
        }
        viewModel.onStart()

        let result = viewModel.showThankYouMessage()

        XCTAssertTrue(result)
        XCTAssertEqual(shownSurveyId, survey.id)
    }

    func testSurveyListSubmittedPublishesBatchSubmittedEvent() {
        let survey = Self.makeSurveyContent(type: .list, modules: [Self.makeStep(id: 1)])
        var event: SDKEvent?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { event = $0 }
        viewModel.onStart()

        viewModel.onSurveyListSubmitted(answersPayload: [["value": "answer"]])

        XCTAssertEqual(event?.eventName, SDKEventsName.surveyExperienceSubmitted.rawValue)
        XCTAssertEqual(event?.eventPayload["survey_id"] as? Int, survey.id)
        XCTAssertNotNil(event?.eventPayload["feedback"])
    }

    func testMoveToNextSurveyStepSubmitsAnswerAndBindsNextStep() {
        let survey = Self.makeSurveyContent(modules: [
            Self.makeStep(id: 1),
            Self.makeStep(id: 2)
        ])
        var eventNames: [String] = []
        var didBindNext = false
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { eventNames.append($0.eventName) }
        viewModel.bindNextSurveyStep = { didBindNext = true }
        viewModel.onStart()

        viewModel.moveToNextSurveyStep("answer", ["value": "answer"])

        XCTAssertEqual(viewModel.currentStep, 1)
        XCTAssertTrue(didBindNext)
        XCTAssertEqual(eventNames, [
            SDKEventsName.surveyExperienceStepSubmitted.rawValue,
            SDKEventsName.surveyExperienceStepSeen.rawValue
        ])
    }

    func testMoveToNextSurveyStepSkipsNilAnswerAndClosesOnLastQuestion() {
        let survey = Self.makeSurveyContent(modules: [Self.makeStep(id: 1)])
        var eventNames: [String] = []
        var didClose = false
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { eventNames.append($0.eventName) }
        viewModel.closeSurvey = { didClose = true }
        viewModel.onStart()

        viewModel.moveToNextSurveyStep(nil, nil)

        XCTAssertTrue(didClose)
        XCTAssertEqual(eventNames, [
            SDKEventsName.surveyExperienceStepSkipped.rawValue,
            SDKEventsName.surveyExperienceCompleted.rawValue
        ])
    }

    func testCompletedStepTriggersDeepLinkAndClose() {
        let survey = Self.makeSurveyContent(modules: [
            Self.makeCompletedStep(id: 1, enabled: true, deepLink: "https://example.com/thanks")
        ])
        var triggeredURL: URL?
        var didClose = false
        var eventName: String?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onTriggerDeepLink = { triggeredURL = $0 }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { eventName = $0.eventName }
        viewModel.closeSurvey = { didClose = true }
        viewModel.onStart()

        viewModel.moveToNextSurveyStep(nil, nil)

        XCTAssertEqual(triggeredURL?.absoluteString, "https://example.com/thanks")
        XCTAssertEqual(eventName, SDKEventsName.surveyExperienceCompleted.rawValue)
        XCTAssertTrue(didClose)
    }

    func testDismissAndDismissalCompletionForwardExpectedEvents() {
        let survey = Self.makeSurveyContent(type: .step, modules: [Self.makeStep(id: 10, type: .openText)])
        var event: SDKEvent?
        var didFinish = false
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { event = $0 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { didFinish = true }
        viewModel.onStart()

        viewModel.onSurveyDismissed()
        viewModel.onExperienceDismissalCompleted()

        XCTAssertEqual(event?.eventName, SDKEventsName.surveyExperienceDismissed.rawValue)
        XCTAssertEqual(event?.eventPayload["module_id"] as? Int, 10)
        XCTAssertEqual(event?.eventPayload["type"] as? String, SurveyViewType.openText.rawValue)
        XCTAssertTrue(didFinish)
    }

    private static func makeSurveyContent(
        id: Int = 12,
        type: SurveyType = .step,
        localeCode: String = "en",
        modules: [SurveyStep]
    ) -> SurveyContent {
        SurveyContent(
            id: id,
            type: type,
            modules: modules,
            metadata: SurveyContentMetaData(buttonLabel: "Continue"),
            surveyTheme: MockContentFactory.makeSurveyMobileTheme(),
            screens: [],
            screenType: .all,
            localeCode: localeCode,
            timeDelay: 0
        )
    }

    private static func makeStep(
        id: Int,
        required: Bool? = false,
        type: SurveyViewType = .likert
    ) -> SurveyStep {
        SurveyStep(
            id: id,
            isRequired: required,
            logic: nil,
            metadata: MockContentFactory.makeSurveyMetadata(),
            question: "Question \(id)",
            subheader: nil,
            type: type,
            buttonLabel: "Next"
        )
    }

    private static func makeCompletedStep(
        id: Int,
        enabled: Bool?,
        deepLink: String? = nil
    ) -> SurveyStep {
        SurveyStep(
            id: id,
            isRequired: false,
            logic: nil,
            metadata: Metadata(
                highScore: nil,
                lowScore: nil,
                range: nil,
                type: nil,
                placeholder: nil,
                choices: nil,
                isMultiSelect: nil,
                otherChoice: nil,
                enablePropertyCreation: nil,
                inputType: nil,
                maxLength: nil,
                propertyName: nil,
                buttonAction: deepLink == nil ? .doNothing : .deepLink,
                iosDeepLink: deepLink,
                enabled: enabled
            ),
            question: nil,
            subheader: nil,
            type: .completed,
            buttonLabel: "Done"
        )
    }
}
