//
//  ExperienceContentTests.swift
//  Userpilot SDK
//

import XCTest
@testable import Userpilot

final class ExperienceContentTests: XCTestCase {

    func testExperienceContentAccessorsReturnAssociatedValues() throws {
        let flow = try makeFlowContent()
        let survey = MockContentFactory.makeSurveyContent(id: 12)
        let nps = try makeNPSContent()

        let flowContent = ExperienceContent.flow(content: flow)
        let surveyContent = ExperienceContent.survey(content: survey)
        let npsContent = ExperienceContent.nps(content: nps)

        XCTAssertEqual(flowContent.asFlowContent()?.id, flow.id)
        XCTAssertNil(flowContent.asSurveyContent())
        XCTAssertEqual(surveyContent.asSurveyContent()?.id, survey.id)
        XCTAssertNil(surveyContent.asNPSContent())
        XCTAssertEqual(npsContent.asNPSContent()?.localeCode, nps.localeCode)
        XCTAssertNil(npsContent.asFlowContent())
    }

    func testExperienceContentLocaleAndThemeId() throws {
        let flow = try makeFlowContent()
        let survey = MockContentFactory.makeSurveyContent(id: 12)
        let nps = try makeNPSContent()

        XCTAssertEqual(ExperienceContent.flow(content: flow).experienceLocale(), flow.localeCode)
        XCTAssertEqual(ExperienceContent.flow(content: flow).experienceThemeId(), flow.baseThemeId)
        XCTAssertEqual(ExperienceContent.survey(content: survey).experienceLocale(), survey.localeCode)
        XCTAssertEqual(ExperienceContent.survey(content: survey).experienceThemeId(), survey.baseThemeId)
        XCTAssertEqual(ExperienceContent.nps(content: nps).experienceLocale(), nps.localeCode)
        XCTAssertEqual(ExperienceContent.nps(content: nps).experienceThemeId(), 0)
    }

    func testExperienceContentContentReturnsTypedAssociatedValue() throws {
        let flow = try makeFlowContent()
        let survey = MockContentFactory.makeSurveyContent(id: 12)
        let nps = try makeNPSContent()

        XCTAssertTrue(ExperienceContent.flow(content: flow).content() is FlowContent)
        XCTAssertTrue(ExperienceContent.survey(content: survey).content() is SurveyContent)
        XCTAssertTrue(ExperienceContent.nps(content: nps).content() is NPSContent)
    }

    func testFixturePayloadsDecodeFlowSurveyNPSAndThemeContent() throws {
        let flow = try makeFlowContent()
        let survey = try makeSurveyContent()
        let nps = try makeNPSContent()
        let theme = try XCTUnwrap(Self.themePayload().toJSONString()?.toMobileTheme())

        XCTAssertEqual(flow.id, 77)
        XCTAssertEqual(flow.type, .carousel)
        XCTAssertEqual(flow.steps.first?.id, 114)
        XCTAssertEqual(survey.id, 12)
        XCTAssertEqual(survey.modules.first?.type, .likert)
        XCTAssertEqual(nps.content.survey.key, "nps_score")
        XCTAssertEqual(theme.id, 99)
        XCTAssertNotNil(theme.themeData?.carousel)
    }

    func testContentScreenTargetingAndDelayHelpers() throws {
        let flow = try makeFlowContent()
        let survey = try makeSurveyContent()
        let nps = try makeNPSContent()

        XCTAssertTrue(flow.isForAllScreens)
        XCTAssertTrue(survey.isForAllScreens)
        XCTAssertEqual(survey.delayDuration, 0)
        XCTAssertTrue(nps.isForAllScreens)
        XCTAssertEqual(nps.delayDuration, 0)
    }

    func testMalformedFixturePayloadsDoNotDecodeAsContent() {
        let invalidJSON = "{"
        let wrongRoot = ["unknown": ["id": 1]].toJSONString()

        XCTAssertNil(invalidJSON.toFlowContent())
        XCTAssertNil(invalidJSON.toSurveyContent())
        XCTAssertNil(invalidJSON.toNPSContent())
        XCTAssertNil(wrongRoot?.toFlowContent())
        XCTAssertNil(wrongRoot?.toSurveyContent())
        XCTAssertNil(wrongRoot?.toNPSContent())
    }

    private func makeFlowContent() throws -> FlowContent {
        try XCTUnwrap(
            MockContentFactory.makeFlowContentPayload()
                .toJSONString()?
                .toFlowContent()?
                .flowContent
        )
    }

    private func makeSurveyContent() throws -> SurveyContent {
        try XCTUnwrap(
            MockContentFactory.makeSurveyContentPayload()
                .toJSONString()?
                .toSurveyContent()?
                .surveyContent
        )
    }

    private func makeNPSContent() throws -> NPSContent {
        try XCTUnwrap(
            MockContentFactory.makeNPSContentPayload()
                .toJSONString()?
                .toNPSContent()?
                .npsContent
        )
    }

    private static func themePayload() -> [String: Any] {
        [
            "id": 99,
            "theme_data": [
                "carousel": [
                    "button": [
                        "background_color": "#000000",
                        "label_color": "#FFFFFF",
                        "border_color": "#000000"
                    ],
                    "colors": [
                        "background_color": "#FFFFFF",
                        "text_color": "#111111",
                        "title_color": "#222222"
                    ],
                    "general": [
                        "content_alignment": "top",
                        "font_family": "Default"
                    ]
                ]
            ]
        ]
    }
}
