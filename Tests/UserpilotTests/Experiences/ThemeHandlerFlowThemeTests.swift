//
//  ThemeHandlerFlowThemeTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the mobile theme's `flow` section, Flow step merging, step backdrops and progress styles.
//

import XCTest
@testable import Userpilot

final class ThemeHandlerFlowThemeTests: XCTestCase {

    private static let baseThemeId = 1

    /// Appex `Schemas.Lookups.MobileThemes.build_flow` for a light theme.
    private static let flowSection = """
        {"general":{"font_family":"Default"},
        "colors":{"background_color":"#FFFFFF","title_color":"#111111","text_color":"#222222"},
        "button":{"background_color":"#7F56D9","label_color":"#FFFFFF","border_color":"#7F56D9",
        "border_width":1,"border_radius":4},
        "dismiss_content":{"enabled":true,"color_type":"automatic","color":"#333333"},
        "backdrop":{"enabled":false,"color":"#000000","opacity":50},
        "progress":{"enabled":true,"style":"dots","color_type":"automatic","color":"#7F56D9"}}
        """

    private var themeHandler: ThemeHandler!

    override func setUp() {
        super.setUp()
        let container = DIContainer()
        container.register(DataStoring.self, value: MockStorage())
        themeHandler = ThemeHandler(container: container)
    }

    override func tearDown() {
        themeHandler = nil
        super.tearDown()
    }

    // MARK: - Decoding

    /// The `flow` section as Appex's theme lookup writes it, next to `carousel`, `slideout` and `survey`.
    func testThemeData_decodesFlowSection() throws {
        let data = try XCTUnwrap(themeReply(section: "\"flow\":\(Self.flowSection)").themeData)
        let flow = try XCTUnwrap(data.flow)

        XCTAssertEqual(flow.general?.fontFamily, "Default")
        XCTAssertEqual(flow.colors?.titleColor, "#111111")
        XCTAssertEqual(flow.button?.borderRadius, 4)
        XCTAssertEqual(flow.dismissContent?.colorType, .automatic)
        assertBackdrop(flow.backdrop, color: "#000000", enabled: false, opacity: 50)
        XCTAssertEqual(flow.progress?.enabled, true)
        XCTAssertEqual(flow.progress?.style, .dots)
        XCTAssertEqual(data.carousel?.button?.backgroundColor, "#CAROUSEL")
    }

    func testThemeData_doesNotDecodeFlowsAsTheFlowSection() throws {
        let data = try XCTUnwrap(themeReply(section: "\"flows\":\(Self.flowSection)").themeData)

        XCTAssertNil(data.flow)
    }

    func testProgressStyle_decodesDotsCounterAndBar_andOnlyBarDrawsABar() throws {
        let themes = try ["dots", "counter", "bar"].map { style in
            let progress = "{\"enabled\":true,\"style\":\"\(style)\",\"color_type\":\"manual\",\"color\":\"#7F56D9\"}"
            return try XCTUnwrap(themeReply(section: "\"flow\":{\"progress\":\(progress)}").themeData?.flow)
        }

        XCTAssertEqual(themes.map { $0.progress?.style }, [.dots, .counter, .bar])
        XCTAssertEqual(themes.map(\.isStepsProgressBar), [false, false, true])
    }

    func testIsStepsProgressBar_keepsDrawingDotsForASurveyType_unlessItIsBar() {
        let ball = ExperienceTheme(progress: ProgressStyle(color: nil, colorType: nil, enabled: true, type: .ball))
        let bar = ExperienceTheme(progress: ProgressStyle(color: nil, colorType: nil, enabled: true, type: .bar))

        XCTAssertFalse(ball.isStepsProgressBar)
        XCTAssertTrue(bar.isStepsProgressBar)
        XCTAssertFalse(ExperienceTheme().isStepsProgressBar)
    }

    // MARK: - Merging

    func testFlowStep_resolvesEachFieldFromStepThenContentThenFlowThenSDKDefault() throws {
        let flowButton = ButtonStyle(
            backgroundColor: "#FLOW", labelColor: "#FLOW", borderColor: "#FLOW", borderWidth: 2, borderRadius: nil)
        let contentButton = ButtonStyle(
            backgroundColor: "#CONTENT", labelColor: "#CONTENT", borderColor: nil, borderWidth: nil, borderRadius: nil)
        saveBaseTheme(flow: ExperienceTheme(button: flowButton))
        let content = flow(
            contentTheme: ExperienceTheme(button: contentButton),
            steps: [step(1, .modal, stepTheme: ExperienceTheme(button: button("#STEP")))]
        )

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        for branch in [merged.carousel, merged.slideOut, merged.tooltip] {
            XCTAssertEqual(branch?.button?.backgroundColor, "#STEP")
            XCTAssertEqual(branch?.button?.labelColor, "#CONTENT")
            XCTAssertEqual(branch?.button?.borderColor, "#FLOW")
            XCTAssertEqual(branch?.button?.borderWidth, 2)
            XCTAssertNil(branch?.button?.borderRadius)
            XCTAssertEqual(branch?.buttonBorderRadius, CGFloat(Constants.Theme.borderRadius))
        }
        XCTAssertNil(merged.survey)
    }

    /// iOS keeps both backdrops on the 0–100 scale; only `backdropOpacity` makes the fraction.
    func testFlowStep_settingsBackdropOverridesEveryThemeBackdrop() throws {
        saveBaseTheme(flow: ExperienceTheme(backdrop: Backdrop(color: "#000000", enabled: false, opacity: 50)))
        let content = flow(
            contentTheme: ExperienceTheme(backdrop: Backdrop(color: "#CONTENT", enabled: false, opacity: 30)),
            steps: [step(
                1,
                .slideout,
                stepTheme: ExperienceTheme(backdrop: Backdrop(color: "#STEP", enabled: false, opacity: 20)),
                backdrop: FlowBackdrop(enabled: true, color: "#112233", opacity: 80)
            )]
        )

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        assertBackdrop(merged.slideOut?.backdrop, color: "#112233", enabled: true, opacity: 80)
        XCTAssertEqual(try XCTUnwrap(merged.slideOut?.backdropOpacity), 0.8, accuracy: 0.0001)
        assertBackdrop(merged.tooltip?.backdrop, color: "#112233", enabled: true, opacity: 80)
        assertBackdrop(merged.carousel?.backdrop, color: "#112233", enabled: true, opacity: 80)
    }

    func testFlowStep_keepsThemeBackdropField_whenStepLeavesItUnset() throws {
        saveBaseTheme(flow: ExperienceTheme(backdrop: Backdrop(color: "#000000", enabled: false, opacity: 50)))
        let content = flow(steps: [step(1, .tooltip, backdrop: FlowBackdrop(enabled: true, color: nil, opacity: nil))])

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        assertBackdrop(merged.tooltip?.backdrop, color: "#000000", enabled: true, opacity: 50)
    }

    func testFlowTooltipSteps_eachCarryTheirOwnSettingsBackdrop() {
        saveBaseTheme(flow: ExperienceTheme())
        let content = flow(steps: [
            step(1, .tooltip, backdrop: FlowBackdrop(enabled: true, color: "#112233", opacity: 60)),
            step(2, .tooltip, backdrop: FlowBackdrop(enabled: false, color: "#112233", opacity: 0))
        ])

        let themes = themeHandler.flowThemes(for: content, isFlowSegment: true)

        XCTAssertEqual(themes.map { $0.tooltip?.backdropEnabled }, [true, false])
        XCTAssertEqual(themes.map { $0.tooltip?.backdrop?.opacity }, [60, 0])
    }

    func testFlowStep_fallsBackToEachStepTypesOwnSection_whenThemeHasNoFlow() throws {
        saveBaseTheme(flow: nil)
        let content = flow(steps: [step(1, .modal)])

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        XCTAssertEqual(merged.carousel?.button?.backgroundColor, "#CAROUSEL")
        XCTAssertEqual(merged.slideOut?.button?.backgroundColor, "#SLIDEOUT")
        XCTAssertEqual(merged.tooltip?.button?.backgroundColor, "#TOOLTIP")
    }

    func testSlideoutFlowStep_keepsProgress_whileStandaloneSlideoutDropsIt() throws {
        let progress = ProgressStyle(color: "#7F56D9", colorType: .manual, enabled: true, type: nil, style: .bar)
        let base = baseTheme(flow: ExperienceTheme(progress: progress))
        themeHandler.saveTheme(ThemeContent(
            id: Self.baseThemeId,
            title: nil,
            themeData: ThemeData(
                carousel: base.carousel,
                slideOut: ExperienceTheme(progress: progress),
                survey: nil,
                tooltip: base.tooltip,
                flow: base.flow
            )
        ))
        let content = flow(steps: [step(1, .slideout)])

        let flowStep = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)
        let standalone = try XCTUnwrap(themeHandler.flowThemes(for: content).first)

        XCTAssertEqual(flowStep.slideOut?.isStepsProgressEnabled, true)
        XCTAssertEqual(flowStep.slideOut?.isStepsProgressBar, true)
        XCTAssertEqual(flowStep.carousel?.progress?.style, .bar)
        XCTAssertEqual(flowStep.carousel?.progress?.color, "#7F56D9")
        XCTAssertNil(standalone.slideOut?.progress)
        XCTAssertNil(standalone.flow)
    }

    /// A layer that only sets `type` still outranks a lower layer's `style`.
    func testFlowStep_resolvesProgressStylePerLayer_beforeMerging() throws {
        saveBaseTheme(flow: ExperienceTheme(
            progress: ProgressStyle(color: nil, colorType: nil, enabled: true, type: nil, style: .bar)))
        let stepProgress = ProgressStyle(color: nil, colorType: nil, enabled: nil, type: .dots)
        let content = flow(steps: [step(1, .modal, stepTheme: ExperienceTheme(progress: stepProgress))])

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        XCTAssertEqual(merged.carousel?.progress?.style, .dots)
        XCTAssertEqual(merged.carousel?.isStepsProgressBar, false)
        XCTAssertEqual(merged.carousel?.isStepsProgressEnabled, true)
    }

    func testAppTheme_replacesFlowStyling_butKeepsStepSettingsBackdrop() throws {
        saveBaseTheme(flow: ExperienceTheme(button: button("#FLOW")))
        themeHandler.setAppTheme(name: "Dark")
        _ = themeHandler.saveAppTheme(
            ThemeContent(id: 9, title: "Dark", themeData: baseTheme(flow: ExperienceTheme(button: button("#APP")))),
            title: "Dark"
        )
        let content = flow(
            contentTheme: ExperienceTheme(button: button("#CONTENT")),
            steps: [step(
                1,
                .tooltip,
                stepTheme: ExperienceTheme(button: button("#STEP")),
                backdrop: FlowBackdrop(enabled: true, color: "#112233", opacity: 70)
            )]
        )

        let merged = try XCTUnwrap(themeHandler.flowThemes(for: content, isFlowSegment: true).first)

        XCTAssertEqual(merged.tooltip?.button?.backgroundColor, "#APP")
        assertBackdrop(merged.tooltip?.backdrop, color: "#112233", enabled: true, opacity: 70)
    }

    // MARK: - Helpers

    /// A `fetch_theme` reply whose `theme_data` also holds `section`.
    private func themeReply(section: String) throws -> ThemeContent {
        let json = """
            {"id":\(Self.baseThemeId),"theme_data":{
            "carousel":{"button":{"background_color":"#CAROUSEL"}},"slideout":null,"survey":null,\(section)}}
            """
        return try XCTUnwrap(json.toMobileTheme())
    }

    private func button(_ background: String) -> ButtonStyle {
        ButtonStyle(backgroundColor: background, labelColor: nil, borderColor: nil, borderWidth: nil, borderRadius: nil)
    }

    /// Each per-type section has its own button color, so a fallback names the section it used.
    private func baseTheme(flow: ExperienceTheme?) -> ThemeData {
        ThemeData(
            carousel: ExperienceTheme(button: button("#CAROUSEL")),
            slideOut: ExperienceTheme(button: button("#SLIDEOUT")),
            survey: nil,
            tooltip: ExperienceTheme(button: button("#TOOLTIP")),
            flow: flow
        )
    }

    private func saveBaseTheme(flow: ExperienceTheme?) {
        themeHandler.saveTheme(ThemeContent(id: Self.baseThemeId, title: nil, themeData: baseTheme(flow: flow)))
    }

    private func step(
        _ id: Int,
        _ type: FlowStepType,
        stepTheme: ExperienceTheme? = nil,
        backdrop: FlowBackdrop? = nil
    ) -> Step {
        Step(
            id: id,
            order: id,
            sections: [],
            buttonAction: nil,
            mobileTheme: stepTheme,
            position: id,
            stepType: type,
            settings: FlowStepSettings(
                position: nil, advanceOn: nil, fallback: nil, dismissAction: nil, backdrop: backdrop)
        )
    }

    private func flow(contentTheme: ExperienceTheme? = nil, steps: [Step]) -> FlowContent {
        FlowContent(
            id: 77,
            type: .flow,
            steps: steps,
            mobileTheme: ContentMobileTheme(id: Self.baseThemeId, themeData: contentTheme),
            screens: [],
            screenType: .all,
            localeCode: "en",
            stepsCount: steps.count
        )
    }

    private func assertBackdrop(
        _ backdrop: Backdrop?,
        color: String?,
        enabled: Bool?,
        opacity: Int?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(backdrop?.color, color, file: file, line: line)
        XCTAssertEqual(backdrop?.enabled, enabled, file: file, line: line)
        XCTAssertEqual(backdrop?.opacity, opacity, file: file, line: line)
    }
}

extension ThemeHandlerFlowThemeTests {
    func testModalPositionOverridesThemeAlignmentPerStep() throws {
        let theme = ExperienceTheme(general: GeneralStyle(contentAlignment: .middle, fontFamily: "Inter"))
        saveBaseTheme(flow: theme)
        let steps = try ["top", "middle", "center"].enumerated().map { index, position in
            let json = """
                {"id":\(index + 1),"order":\(index),"sections":[],"step_type":"modal",
                 "settings":{"position":"\(position)"}}
                """
            return try JSONDecoder().decode(Step.self, from: Data(json.utf8))
        } + [step(4, .modal)]
        let content = flow(steps: steps)
        let themes = themeHandler.flowThemes(for: content, isFlowSegment: true)

        XCTAssertEqual(themes.map { $0.carousel?.general?.contentAlignment }, [.top, .middle, .middle, .middle])
        XCTAssertEqual(themes.first?.carousel?.fontFamily, "Inter")

        themeHandler.setAppTheme(name: "App")
        let app = ExperienceTheme(general: GeneralStyle(contentAlignment: .top, fontFamily: "AppFont"))
        _ = themeHandler.saveAppTheme(ThemeContent(id: 9, title: "App", themeData: baseTheme(flow: app)), title: "App")
        let appThemes = themeHandler.flowThemes(for: content, isFlowSegment: true)
        XCTAssertEqual(appThemes.map { $0.carousel?.general?.contentAlignment }, [.top, .middle, .middle, .top])
        XCTAssertEqual(appThemes.first?.carousel?.fontFamily, "AppFont")
    }
}
