//
//  NPSViewModelTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class NPSViewModelTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var viewModel: NPSViewModel!

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot(
            config: Userpilot.Config(token: "NPS-VM-\(UUID().uuidString)").defaultInstance(false)
        )
        viewModel = NPSViewModel(container: userpilot.container)
    }

    override func tearDown() {
        viewModel = nil
        userpilot = nil
        super.tearDown()
    }

    func testOnStartBindsFalseWhenNoNPSContentExists() {
        var didBind: Bool?
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, false)
    }

    func testOnStartBindsNPSContentAndTheme() throws {
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        var didBind: Bool?
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        viewModel.bindData = { didBind = $0 }

        viewModel.onStart()

        XCTAssertEqual(didBind, true)
        XCTAssertEqual(viewModel.npsContent?.content.survey.key, "nps_score")
        XCTAssertNotNil(viewModel.npsTheme)
        XCTAssertFalse(viewModel.isRTL)
    }

    func testNPSDismissedAndSubmittedPublishExpectedEvents() throws {
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        var events: [SDKEvent] = []
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { events.append($0) }
        viewModel.onStart()

        viewModel.onNPSDismissed()
        viewModel.onNPSSubmitted(10, "feedback-key", "Loved it")

        XCTAssertEqual(events.map(\.eventName), [
            SDKEventsName.npsExperienceDismissed.rawValue,
            SDKEventsName.npsExperienceSubmitted.rawValue
        ])
        XCTAssertEqual(events.last?.eventPayload["score"] as? Int, 9)
        XCTAssertEqual(events.last?.eventPayload["survey_question_key"] as? String, "nps_score")
        XCTAssertEqual(events.last?.eventPayload["feedback"] as? String, "Loved it")
        XCTAssertEqual(events.last?.eventPayload["follow_up_question_key"] as? String, "feedback-key")
    }

    func testEndNPSDeepLinkAndDismissalCompletionForwardToPublisher() {
        let completedData = CompletedData(
            header: "Thanks",
            subheader: nil,
            button: ButtonData(
                buttonText: "Open",
                close: nil,
                enabled: true,
                iosDeepLink: "https://example.com/nps",
                buttonAction: .deepLink
            )
        )
        var triggeredURL: URL?
        var didFinish = false
        userpilot.experiencesPublisher.onTriggerDeepLink = { triggeredURL = $0 }
        userpilot.experiencesPublisher.onExperienceDidFinishDismissing = { didFinish = true }

        viewModel.endNPS(completedData)
        viewModel.onExperienceDismissalCompleted()

        XCTAssertEqual(triggeredURL?.absoluteString, "https://example.com/nps")
        XCTAssertTrue(didFinish)
    }
}
