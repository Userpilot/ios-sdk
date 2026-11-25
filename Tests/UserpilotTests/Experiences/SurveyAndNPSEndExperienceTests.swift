//
//  SurveyAndNPSEndExperienceTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 25/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The host app's `endExperience()` reports a step survey or NPS as dismissed, like the user's own close.
//  A navigation close stays silent, and a close already in flight does not report twice.
//

import XCTest
@testable import Userpilot

final class SurveyAndNPSEndExperienceTests: XCTestCase {

    private var userpilot: MockUserpilot!
    private var eventNames: [String] = []

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot.make(
            config: Userpilot.Config(token: "END-EXPERIENCE-\(UUID().uuidString)").defaultInstance(false)
        )
        userpilot.themeHandler.onMergeSurveyThemes = { _, surveyTheme in
            surveyTheme ?? MockContentFactory.makeSurveyTheme()
        }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { [weak self] in
            self?.eventNames.append($0.eventName)
        }
        eventNames = []
    }

    override func tearDown() {
        userpilot = nil
        super.tearDown()
    }

    func testEndExperience_reportsAStepSurveyDialogDismissedOnce() {
        let renderer = SurveyDialogViewController(surveyViewModel: startedSurveyViewModel())

        closeTwice(renderer)

        XCTAssertEqual(eventNames, [SDKEventsName.surveyExperienceDismissed.rawValue])
    }

    func testEndExperience_reportsAStepSurveyBottomSheetDismissedOnce() {
        let renderer = SurveyBottomSheetViewController(surveyViewModel: startedSurveyViewModel())

        closeTwice(renderer)

        XCTAssertEqual(eventNames, [SDKEventsName.surveyExperienceDismissed.rawValue])
    }

    func testEndExperience_reportsAnNPSDismissedOnce() throws {
        let renderer = NPSBottomSheetViewController(npsViewModel: try startedNPSViewModel())

        closeTwice(renderer)

        XCTAssertEqual(eventNames, [SDKEventsName.npsExperienceDismissed.rawValue])
    }

    func testANavigationClose_leavesASurveyAndAnNPSSilent() throws {
        let renderers: [UPExperienceDelegate] = [
            SurveyDialogViewController(surveyViewModel: startedSurveyViewModel()),
            SurveyBottomSheetViewController(surveyViewModel: startedSurveyViewModel()),
            NPSBottomSheetViewController(npsViewModel: try startedNPSViewModel())
        ]

        renderers.forEach { $0.triggerCloseExperience(manualClose: false, completion: {}) }

        XCTAssertEqual(eventNames, [])
    }

    // MARK: - Helpers

    private func closeTwice(_ renderer: UPExperienceDelegate) {
        renderer.triggerCloseExperience(manualClose: true, completion: {})
        renderer.triggerCloseExperience(manualClose: true, completion: {})
    }

    private func startedSurveyViewModel() -> SurveyViewModel {
        let survey = MockContentFactory.makeSurveyContent()
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
        let viewModel = SurveyViewModel(container: userpilot.container)
        viewModel.onStart()
        eventNames = []
        return viewModel
    }

    private func startedNPSViewModel() throws -> NPSViewModel {
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .nps(content: nps) }
        let viewModel = NPSViewModel(container: userpilot.container)
        viewModel.onStart()
        eventNames = []
        return viewModel
    }
}
