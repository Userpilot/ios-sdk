//
//  ThemeHandlerTests+AppTheme.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the host app theme's resolution, fallback and style-versus-placement rules.
//

import XCTest
@testable import Userpilot

extension ThemeHandlerTests {

    func testRequiredThemeKey_isContentThemeId_whenNoAppThemeIsSelected() throws {
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .id(1))
    }

    func testRequiredThemeKey_isNil_forNPS() throws {
        themeHandler.setAppTheme(name: "Dark")
        let nps = try XCTUnwrap(MockContentFactory.makeNPSContentPayload().toJSONString()?.toNPSContent()?.npsContent)

        XCTAssertNil(themeHandler.requiredThemeKey(for: .nps(content: nps)))
    }

    func testRequiredThemeKey_isAppThemeTitle_untilItIsFetched() throws {
        themeHandler.setAppTheme(name: "Dark")
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .title("Dark"))
        XCTAssertNil(themeHandler.appTheme)

        XCTAssertTrue(themeHandler.saveAppTheme(try appThemeReply(title: "Dark"), title: "Dark"))

        XCTAssertNil(themeHandler.requiredThemeKey(for: try flow()))
        XCTAssertNotNil(themeHandler.appTheme)
    }

    func testSaveAppTheme_rejectsReplyForAnotherTitle() throws {
        themeHandler.setAppTheme(name: "Dark")

        XCTAssertFalse(themeHandler.saveAppTheme(try appThemeReply(title: "Light"), title: "Dark"))
        XCTAssertNil(themeHandler.appTheme)
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .title("Dark"))
    }

    func testUnavailableAppTheme_fallsBackToContentTheme() throws {
        themeHandler.setAppTheme(name: "Dark")
        themeHandler.markAppThemeUnavailable("Dark")

        XCTAssertNil(themeHandler.appTheme)
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .id(1))
    }

    func testResetAppThemes_refetchesTitle_butKeepsResolvedTheme() throws {
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark"), title: "Dark")
        themeHandler.markAppThemeUnavailable("Light")

        themeHandler.resetAppThemes()

        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .title("Dark"))
        XCTAssertNotNil(themeHandler.appTheme)
    }

    func testSetAppTheme_keepsPreviousTheme_untilNewTitleIsFetched() throws {
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark", buttonColor: "#DARK"), title: "Dark")

        themeHandler.setAppTheme(name: "Light")
        XCTAssertEqual(themeHandler.appTheme?.carousel?.button?.backgroundColor, "#DARK")
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .title("Light"))

        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Light", buttonColor: "#LIGHT"), title: "Light")
        XCTAssertEqual(themeHandler.appTheme?.carousel?.button?.backgroundColor, "#LIGHT")

        themeHandler.setAppTheme(name: "Dark")
        XCTAssertEqual(themeHandler.appTheme?.carousel?.button?.backgroundColor, "#DARK")
    }

    func testSetAppTheme_nil_restoresContentThemes() throws {
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark"), title: "Dark")

        themeHandler.setAppTheme(name: nil)

        XCTAssertNil(themeHandler.appTheme)
        XCTAssertEqual(themeHandler.requiredThemeKey(for: try flow()), .id(1))
    }

    func testFlowThemes_replaceContentAndStepStyling_whenAppThemeIsResolved() throws {
        let content = try flowContent()
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark", buttonColor: "#APP"), title: "Dark")

        let themes = themeHandler.flowThemes(for: content)

        XCTAssertEqual(themes.count, content.steps.count)
        XCTAssertEqual(themes.map { $0.carousel?.button?.backgroundColor }, content.steps.map { _ in "#APP" })
    }

    func testFlowThemes_keepStepOverrides_withoutAppTheme() throws {
        let themes = themeHandler.flowThemes(for: try flowContent())

        XCTAssertEqual(themes.first?.carousel?.button?.backgroundColor, "#002E01")
    }

    func testSurveyTheme_usesAppTheme_whenResolved() throws {
        let survey = try XCTUnwrap(
            MockContentFactory.makeSurveyContentPayload().toJSONString()?.toSurveyContent()?.surveyContent
        )
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark"), title: "Dark")

        XCTAssertEqual(themeHandler.surveyTheme(for: survey).general?.backgroundColor, "#111111")
    }

    func testFlowThemes_useAppThemeAlignment_overContentAlignment() throws {
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark", alignment: "bottom"), title: "Dark")

        let theme = try XCTUnwrap(themeHandler.flowThemes(for: try flowContent()).first)

        XCTAssertEqual(theme.slideOut?.general?.contentAlignment, .bottom)
        XCTAssertNil(theme.carousel?.general?.contentAlignment)
        XCTAssertNil(theme.carousel?.general?.fontFamily)
    }

    func testSurveyTheme_usesAppThemePosition_overContentPosition() throws {
        let survey = try surveyContent(position: "bottom")
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dark", surveyPosition: "center"), title: "Dark")

        XCTAssertEqual(themeHandler.surveyTheme(for: survey).general?.position, .center)
    }

    func testIsBottomSheet_followsAppTheme_overContentPlacement() throws {
        themeHandler.setAppTheme(name: "Sheet")
        _ = themeHandler.saveAppTheme(
            try appThemeReply(title: "Sheet", alignment: "bottom", surveyPosition: "center"), title: "Sheet"
        )

        XCTAssertTrue(try flowContent().isBottomSheet(using: themeHandler))
        XCTAssertFalse(try surveyContent(position: "bottom").isBottomSheet(using: themeHandler))
    }

    func testIsBottomSheet_usesAppTheme_whenContentHasNoPlacement() throws {
        let flow = try flowContent(embeddedTheme: false)
        let survey = try surveyContent()
        themeHandler.setAppTheme(name: "Sheet")
        _ = themeHandler.saveAppTheme(
            try appThemeReply(title: "Sheet", alignment: "bottom", surveyPosition: "bottom"), title: "Sheet"
        )
        XCTAssertTrue(flow.isBottomSheet(using: themeHandler))
        XCTAssertTrue(survey.isBottomSheet(using: themeHandler))

        themeHandler.setAppTheme(name: "Dialog")
        _ = themeHandler.saveAppTheme(try appThemeReply(title: "Dialog"), title: "Dialog")
        XCTAssertFalse(flow.isBottomSheet(using: themeHandler))
        XCTAssertFalse(survey.isBottomSheet(using: themeHandler))
    }

    func testThemeContent_decodesTitle() throws {
        XCTAssertEqual(try appThemeReply(title: "Brand Dark").title, "Brand Dark")
    }

    /// The analytex `fetch_theme` reply for a dashboard mobile theme, captured from a device run.
    func testFetchThemeReply_decodesEveryStyleGroup() throws {
        let reply = try XCTUnwrap(Self.darkThemeReply.toMobileTheme())
        XCTAssertTrue(themeHandler.saveAppTheme(reply, title: "Dark Theme"))
        let data = try XCTUnwrap(reply.themeData)

        XCTAssertEqual(reply.id, 2)
        XCTAssertEqual(data.carousel?.colors?.backgroundColor, "#000003")
        XCTAssertEqual(data.carousel?.button?.labelColor, "#000003")
        XCTAssertEqual(data.carousel?.dismissContent?.colorType, .manual)
        XCTAssertEqual(data.carousel?.general?.contentAlignment, .top)
        XCTAssertEqual(data.carousel?.progress?.enabled, true)
        XCTAssertEqual(data.slideOut?.general?.contentAlignment, .center)
        XCTAssertEqual(data.slideOut?.backdrop?.opacity, 50)
        XCTAssertEqual(data.slideOut?.button?.borderRadius, 0)
        XCTAssertEqual(data.survey?.general?.position, .bottom)
        XCTAssertEqual(data.survey?.general?.cornerRadius, 3)
        XCTAssertEqual(data.survey?.font?.fontFamily, "Serif")
        XCTAssertEqual(data.survey?.progress?.type, .ball)
        XCTAssertTrue(data.isDialogExperience)
        XCTAssertFalse(data.isDialogSurvey)
    }

    private static let darkThemeReply = """
    {"title":"Dark Theme","id":2,"request_type":"fetch_theme","hidden":0,"primary_theme":0,"theme_data":{\
    "survey":{"progress":{"color":"#F4F4F5","enabled":true,"type":"ball"},\
    "font":{"font_family":"Serif","color_type":"automatic","font_color":"#F4F4F5"},\
    "backdrop":{"color":"#F4F4F5","enabled":true,"opacity":50},\
    "general":{"default_position":"bottom","primary_color":"#F4F4F5","background_color":"#000003","corner_radius":3}},\
    "slideout":{"colors":{"background_color":"#000003","text_color":"#F4F4F5","title_color":"#F4F4F5"},\
    "dismiss_content":{"color":"#F4F4F5","color_type":"manual","enabled":true},\
    "button":{"label_color":"#000003","background_color":"#F4F4F5","border_color":"#000003",\
    "border_radius":0,"border_width":0},\
    "backdrop":{"color":"#F4F4F5","enabled":true,"opacity":50},\
    "general":{"font_family":"Serif","content_alignment":"center"}},\
    "carousel":{"colors":{"background_color":"#000003","text_color":"#F4F4F5","title_color":"#F4F4F5"},\
    "dismiss_content":{"color":"#F4F4F5","color_type":"manual","enabled":true},\
    "button":{"label_color":"#000003","background_color":"#F4F4F5","border_color":"#000003",\
    "border_radius":0,"border_width":0},\
    "general":{"font_family":"Serif","content_alignment":"top"},\
    "progress":{"color":"#F4F4F5","color_type":"manual","enabled":true}}}}
    """

    // MARK: - Helpers

    /// Without the embedded theme, placement falls back to the base theme.
    private func flowContent(embeddedTheme: Bool = true) throws -> FlowContent {
        var payload = MockContentFactory.makeFlowContentPayload()
        if !embeddedTheme, var flow = payload["mobile_contents"] as? [String: Any] {
            flow["theme_data"] = ["id": 1, "theme_id": 1]
            payload["mobile_contents"] = flow
        }
        return try XCTUnwrap(payload.toJSONString()?.toFlowContent()?.flowContent)
    }

    /// The survey fixture embeds no position unless one is given.
    private func surveyContent(position: String? = nil) throws -> SurveyContent {
        var payload = MockContentFactory.makeSurveyContentPayload()
        if let position, var survey = payload["surveys"] as? [String: Any] {
            survey["theme_data"] = ["id": 4, "theme_data": ["general": ["default_position": position]]]
            payload["surveys"] = survey
        }
        return try XCTUnwrap(payload.toJSONString()?.toSurveyContent()?.surveyContent)
    }

    private func flow() throws -> ExperienceContent {
        .flow(content: try flowContent())
    }

    private func appThemeReply(
        title: String,
        buttonColor: String = "#APP",
        alignment: String = "center",
        surveyPosition: String = "center"
    ) throws -> ThemeContent {
        let json = """
        {
            "id": 9,
            "title": "\(title)",
            "theme_data": {
                "carousel": { "button": { "background_color": "\(buttonColor)" } },
                "slideout": {
                    "button": { "background_color": "\(buttonColor)" },
                    "general": { "content_alignment": "\(alignment)" }
                },
                "survey": { "general": { "default_position": "\(surveyPosition)", "background_color": "#111111" } }
            }
        }
        """
        return try XCTUnwrap(json.toMobileTheme())
    }
}
