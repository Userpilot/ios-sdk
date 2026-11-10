//
//  UPExperienceStyleTests.swift
//  Userpilot SDK
//
//  Pins how a theme resolves into the style widgets draw with; Android's ExperienceStyleTest pins the same rules.
//

import XCTest
@testable import Userpilot

final class UPExperienceStyleTests: XCTestCase {
    func testASurveyDrawsButtonsInThePrimaryWithItsOppositeAsText() {
        let style = MockContentFactory.makeSurveyTheme().experienceStyle
        XCTAssertEqual(style.primary, "#007AFF".color)
        XCTAssertEqual(style.buttonText, "#007AFF".invertColor().color)
        XCTAssertEqual(style.buttonRadius, 12)
        XCTAssertEqual(style.fontName, "Arial")
    }

    func testAManualProgressColorDrawsTheBarAndEveryDot() {
        let style = MockContentFactory.makeSurveyTheme().experienceStyle
        XCTAssertTrue(style.progress)
        XCTAssertTrue(style.dots)
        XCTAssertEqual(style.progressColor, "#00FF00".color)
        XCTAssertEqual(style.inactiveProgressColor, "#00FF00".color)
    }

    func testWithoutAManualColorDotsNotReachedYetUseTheBackgroundsOpposite() {
        let style = surveyTheme(progressColorType: .automatic).experienceStyle
        XCTAssertEqual(style.inactiveProgressColor, "#FFFFFF".invertColor().color)
    }

    func testPlaceholdersAndBordersFadeTheTextColor() {
        let style = UPExperienceStyle(text: .red)
        XCTAssertEqual(style.placeholder, UIColor.red.withAlphaComponent(0.8))
        XCTAssertEqual(style.secondaryText, UIColor.red.withAlphaComponent(0.2))
    }

    func testAStyleRebuiltFromTheSameThemeIsEqual() {
        // Each rebuild reads new color objects from the theme; widgets redraw only when the style is unequal.
        XCTAssertEqual(MockContentFactory.makeSurveyTheme().experienceStyle,
                       MockContentFactory.makeSurveyTheme().experienceStyle)
        XCTAssertNotEqual(MockContentFactory.makeSurveyTheme().experienceStyle,
                          surveyTheme(progressColorType: .automatic).experienceStyle)
    }

    private func surveyTheme(progressColorType: ColorType) -> SurveyTheme {
        let base = MockContentFactory.makeSurveyTheme()
        return SurveyTheme(
            general: base.general, font: base.font,
            progress: ProgressStyle(color: "#00FF00", colorType: progressColorType, enabled: true, type: .ball),
            backdrop: base.backdrop)
    }
}
