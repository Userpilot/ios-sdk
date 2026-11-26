//
//  ExperienceViewModelTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ExperienceViewModelTests: XCTestCase {

    var userpilot: MockUserpilot!
    var viewModel: ExperienceViewModel!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot.make(
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
        var events: [ExperienceEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "next", deepLink: "https://example.com"))

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
        var events: [ExperienceEvent] = []
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
        var events: [ExperienceEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()
        viewModel.onStepChanged(1)

        viewModel.onDismissStep()

        XCTAssertEqual(events.last?.eventName, SDKEventsName.flowExperienceDismissed.rawValue)
        XCTAssertEqual(events.last?.eventPayload["step_id"] as? Int, 2)
    }

    func testCompletionLinkAndDismissalCompletionForwardToPublisher() throws {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1, deepLink: "https://example.com/deep")])
        var triggeredURL: URL?
        var didFinishDismissing = false
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onSetCompletionDeepLink = { triggeredURL = $0 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { didFinishDismissing = true }
        viewModel.onStart()

        viewModel.setCompletionDeepLink("https://example.com/deep")
        viewModel.onExperienceDismissalCompleted()

        XCTAssertEqual(triggeredURL?.absoluteString, "https://example.com/deep")
        XCTAssertTrue(didFinishDismissing)
    }

    func testStepChangeReportsOutgoingIDToDelegateAndBackend() {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 101), Self.makeStep(id: 102)])
        let delegate = FlowStepDelegate()
        var events: [ExperienceEvent] = []
        userpilot.experienceDelegate = delegate
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()

        viewModel.onStepChanged(1)

        XCTAssertEqual(delegate.states, [.completed, .started])
        XCTAssertEqual(delegate.stepIDs, [101, 102])
        XCTAssertEqual(delegate.positions, [1, 2])
        XCTAssertEqual(events.map { $0.eventPayload["step_id"] as? Int }, [101, 102])
    }

    func testBackNavigationUpdatesVisibleStepWithoutReplayingEngagement() {
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 101), Self.makeStep(id: 102)])
        var events: [ExperienceEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()
        viewModel.onStepChanged(1)
        events.removeAll()

        viewModel.onStepChanged(0)
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertTrue(events.isEmpty)
        viewModel.onDismissStep()

        XCTAssertEqual(events.last?.eventPayload["step_id"] as? Int, 102)
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

// MARK: - Flow mode

extension ExperienceViewModelTests {

    func testFlowStepShown_reportsItsSeenOutcome_withFlowAndStepStarted() {
        let delegate = FlowStepDelegate()
        userpilot.experienceDelegate = delegate
        var outcomes: [FlowStepOutcome] = []
        var standaloneEvents: [ExperienceEvent] = []
        let reported = expectation(description: "seen outcome reported")
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = {
            outcomes.append($0)
            reported.fulfill()
        }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { standaloneEvents.append($0) }
        startFlowStep(position: 1)

        viewModel.onExperienceSeen()
        wait(for: [reported], timeout: 2)

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["seen_mobile_content_step"])
        XCTAssertTrue(standaloneEvents.isEmpty)
        XCTAssertEqual(delegate.flowStates, [.started])
        XCTAssertEqual(delegate.flowIDs, [88])
        XCTAssertEqual(delegate.states, [.started])
        XCTAssertEqual(delegate.stepIDs, [301])
        XCTAssertEqual(delegate.positions, [1])
        XCTAssertEqual(delegate.totals, [3])
    }

    func testASecondAppearance_reportsTheStepSeenOnce() {
        var outcomes: [FlowStepOutcome] = []
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        startFlowStep(position: 1)

        viewModel.onExperienceSeen()
        viewModel.onExperienceSeen()

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["seen_mobile_content_step"])
    }

    func testNextOnAFlowStep_reportsAdvanced_withoutRecordingTheDeepLink() {
        var outcomes: [FlowStepOutcome] = []
        var recordedLink: URL?
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        userpilot.experiencesPublisher.onSetCompletionDeepLink = { recordedLink = $0 }
        startFlowStep(position: 2)

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "next", deepLink: "shop://carts"))

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["completed_mobile_content_step"])
        XCTAssertEqual(outcomes.first?.run.endedStepIds, [301])
        XCTAssertEqual(outcomes.first?.run.hasEnded, false)
        XCTAssertNil(recordedLink)
    }

    func testLinkOnTheFlowsLastStep_recordsTheDeepLinkBeforeReporting() {
        let delegate = FlowStepDelegate()
        userpilot.experienceDelegate = delegate
        var calls: [String] = []
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { calls.append("outcome:\($0.opensDeepLink)") }
        userpilot.experiencesPublisher.onSetCompletionDeepLink = { calls.append("link:\($0.absoluteString)") }
        startFlowStep(position: 3)

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "link", deepLink: "shop://carts"))

        XCTAssertEqual(calls, ["link:shop://carts", "outcome:true"])
        XCTAssertEqual(delegate.states, [.completed])
        XCTAssertEqual(delegate.flowStates, [.completed])
    }

    func testLinkOnAMiddleFlowStep_reportsAdvancedWithoutTheDeepLink() {
        var outcomes: [FlowStepOutcome] = []
        var recordedLink: URL?
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        userpilot.experiencesPublisher.onSetCompletionDeepLink = { recordedLink = $0 }
        startFlowStep(position: 2)

        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "link", deepLink: "shop://carts"))

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["completed_mobile_content_step"])
        XCTAssertEqual(outcomes.first?.opensDeepLink, false)
        XCTAssertNil(recordedLink)
    }

    func testClosingAFlowStep_reportsClosedOnce_andFlowDismissed() {
        let delegate = FlowStepDelegate()
        userpilot.experienceDelegate = delegate
        var outcomes: [FlowStepOutcome] = []
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        startFlowStep(position: 2)

        viewModel.onDismissStep()
        viewModel.onDismissStep()
        viewModel.onExperienceCompleted(ButtonAction(buttonAction: "next", deepLink: nil))

        XCTAssertEqual(outcomes.flatMap { $0.events.map(\.eventName) }, ["dismissed_mobile_content"])
        XCTAssertEqual(outcomes.first?.run.hasEnded, true)
        XCTAssertEqual(delegate.states, [.dismissed])
        XCTAssertEqual(delegate.flowStates, [.dismissed])
    }

    func testPageChangeOnAFlowStep_reportsNothing() {
        var outcomes: [FlowStepOutcome] = []
        var events: [ExperienceEvent] = []
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { outcomes.append($0) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        startFlowStep(position: 2)

        viewModel.onStepChanged(1)

        XCTAssertEqual(viewModel.currentStep, 1)
        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertTrue(events.isEmpty)
    }

    func testProgress_usesTheFlowsStepsCountAndPosition_onlyForAFlowStep() {
        startFlowStep(position: 2)
        XCTAssertEqual(viewModel.progressStepsCount, 3)
        XCTAssertEqual(viewModel.progressStepIndex(0), 1)

        let standalone = ExperienceViewModel(container: userpilot.container)
        let flow = Self.makeFlowContent(steps: [Self.makeStep(id: 1), Self.makeStep(id: 2)])
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        standalone.onStart()
        XCTAssertEqual(standalone.progressStepsCount, 2)
        XCTAssertEqual(standalone.progressStepIndex(1), 1)
    }

    /// Starts the view model on step 301 of Flow 88 (`steps_count` 3), projected onto the carousel.
    func startFlowStep(position: Int) {
        let step = Step(
            id: 301, order: 0, sections: [], buttonAction: ButtonAction(buttonAction: "next", deepLink: nil),
            mobileTheme: ExperienceTheme(), position: position, stepType: .modal
        )
        let content = FlowContent(
            id: 88, type: .carousel, steps: [step],
            mobileTheme: ContentMobileTheme(id: 1, themeData: ExperienceTheme()),
            screens: [], screenType: .all, localeCode: "en", stepsCount: 3
        )
        let segment = FlowSegment(flowId: 88, stepsCount: 3, screen: "Home", run: FlowRun())
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: content, segment: segment) }
        viewModel.onStart()
    }
}
