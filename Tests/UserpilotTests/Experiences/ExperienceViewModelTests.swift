//
//  ExperienceViewModelTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ExperienceViewModelTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var viewModel: ExperienceViewModel!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(
            config: Userpilot.Config(token: "FLOW-VM-\(UUID().uuidString)").defaultInstance(false)
        )
        userpilot.themeHandler.onMergeExperienceThemes = { _, _, _ in
            ThemeData(carousel: ExperienceTheme(), slideOut: ExperienceTheme(), survey: nil)
        }
        viewModel = ExperienceViewModel(container: userpilot.container)
    }

    override func tearDown() {
        viewModel = nil
        userpilot = nil
        super.tearDown()
    }

    func testOnStartBindsFalseWhenNoFlowContentExists() {
        var didBind: Bool?
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, false)
    }

    func testOnStartBindsFlowContentAndMergesThemePerStep() {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1), Self.makeStep(id: 2)])
        var mergeCount = 0
        var didBind: Bool?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.themeHandler.onMergeExperienceThemes = { _, _, _ in
            mergeCount += 1
            return ThemeData(carousel: ExperienceTheme(), slideOut: nil, survey: nil)
        }
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, true)
        XCTAssertEqual(viewModel.carouselStepsCount, 2)
        XCTAssertEqual(mergeCount, 2)
        XCTAssertFalse(viewModel.isRTL)
    }

    func testOnStartBindsFalseForEmptyCarouselSteps() {
        let flow = Self.makeFlowContent(steps: [])
        var didBind: Bool?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, false)
    }

    func testExperienceCompletionPublishesStepAndContentCompletionEvents() throws {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 7, deepLink: "https://example.com")])
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()

        viewModel.onExperienceCompleted()

        XCTAssertEqual(events.map(\.eventName), [
            SDKEventsName.flowExperienceStepCompleted.rawValue,
            SDKEventsName.flowExperienceCompleted.rawValue
        ])
        XCTAssertEqual(events.first?.eventPayload["step_id"] as? Int, 7)
        XCTAssertEqual(events.last?.eventPayload["mobile_content_id"] as? Int, flow.id)
        XCTAssertEqual(events.last?.hasDeepLink, true)
    }

    func testStepChangePublishesPreviousStepCompletedAndCurrentStepSeenOnce() {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1), Self.makeStep(id: 2)])
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()

        viewModel.onStepChanged(1)
        viewModel.onStepChanged(1)

        XCTAssertEqual(events.map(\.eventName), [
            SDKEventsName.flowExperienceStepCompleted.rawValue,
            SDKEventsName.flowExperienceStepSeen.rawValue
        ])
        XCTAssertEqual(events.first?.eventPayload["step_id"] as? Int, 1)
        XCTAssertEqual(events.last?.eventPayload["step_id"] as? Int, 2)
    }

    func testDismissPublishesDismissedEventForLastReachedStep() {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1), Self.makeStep(id: 2)])
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()
        viewModel.onStepChanged(1)

        viewModel.onDismissStep()

        XCTAssertEqual(events.last?.eventName, SDKEventsName.flowExperienceDismissed.rawValue)
        XCTAssertEqual(events.last?.eventPayload["step_id"] as? Int, 2)
    }

    func testDeepLinkAndDismissalCompletionForwardToPublisher() throws {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1, deepLink: "https://example.com/deep")])
        var triggeredURL: URL?
        var didFinishDismissing = false
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onTriggerDeepLink = { triggeredURL = $0 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { didFinishDismissing = true }
        viewModel.onStart()

        viewModel.onDeepLinkTriggered()
        viewModel.onExperienceDismissalCompleted()

        XCTAssertEqual(triggeredURL?.absoluteString, "https://example.com/deep")
        XCTAssertTrue(didFinishDismissing)
    }

    private static func makeFlowContent(
        type: ContentType = .carousel,
        localeCode: String = "en",
        steps: [Step]
    ) -> FlowContent {
        FlowContent(
            id: 77,
            type: type,
            steps: steps,
            mobileTheme: ContentMobileTheme(id: 1, themeData: ExperienceTheme()),
            screens: [],
            screenType: .all,
            localeCode: localeCode
        )
    }

    private static func makeStep(id: Int, deepLink: String? = nil) -> Step {
        Step(
            id: id,
            order: id,
            sections: [],
            buttonAction: ButtonAction(buttonAction: "next", deepLink: deepLink),
            mobileTheme: ExperienceTheme()
        )
    }
}
