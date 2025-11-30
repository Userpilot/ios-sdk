//
//  ThemeHandlerTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 07/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import XCTest
@testable import Userpilot

class ThemeHandlerTests: XCTestCase {

    var themeHandler: ThemeHandler!

    override func setUpWithError() throws {
        super.setUp()
        themeHandler = ThemeHandler()
    }

    override func tearDown() {
        themeHandler = nil
        super.tearDown()
    }

    func testSaveTheme_savesThemeCorrectly_whenValidThemeProvided() {
        // Arrange
        let themeId = 123
        let themeData = ThemeData(carousel: nil, slideOut: nil, survey: nil)
        let themeContent = ThemeContent(id: themeId, themeData: themeData)

        // Act
        themeHandler.saveTheme(themeContent)
        let result = themeHandler.getThemeById(themeId)

        // Assert
        XCTAssertNotNil(result)
    }

    func testGetThemeById_returnsNil_whenThemeIsNotSaved() {
        // Act
        let result = themeHandler.getThemeById(999)

        // Assert
        XCTAssertNil(result)
    }

    func testMergeExperienceThemes_usesStepTheme_whenAvailable() {
        // Arrange
        let base = ThemeData(
            carousel: ExperienceTheme(
                button: ButtonStyle(
                    backgroundColor: "#BASE",
                    labelColor: nil,
                    borderColor: nil,
                    borderWidth: nil,
                    borderRadius: nil
                ),
                colors: nil, dismissContent: nil, general: nil, progress: nil, backdrop: nil
            ),
            slideOut: nil,
            survey: nil
        )

        let global = ExperienceTheme(
            button: ButtonStyle(
                backgroundColor: "#GLOBAL",
                labelColor: nil,
                borderColor: nil,
                borderWidth: nil,
                borderRadius: nil
            ),
            colors: nil, dismissContent: nil, general: nil, progress: nil, backdrop: nil
        )

        let step = ExperienceTheme(
            button: ButtonStyle(
                backgroundColor: "#STEP",
                labelColor: nil,
                borderColor: nil,
                borderWidth: nil,
                borderRadius: nil
            ),
            colors: nil, dismissContent: nil, general: nil, progress: nil, backdrop: nil
        )

        // Act
        let merged = themeHandler.mergeExperienceThemes(base, global, step)

        // Assert
        XCTAssertEqual(merged.carousel?.button?.backgroundColor, "#STEP")
    }

    func testMergeSurveyThemes_mergesCorrectly_whenSomeValuesMissing() {
        // Arrange
        let baseTheme = ThemeData(
            carousel: nil,
            slideOut: nil,
            survey: SurveyTheme(
                general: SurveyGeneral(
                    position: .bottom,
                    primaryColor: "#basePrimary",
                    backgroundColor: "#baseBg",
                    cornerRadius: 10
                ),
                font: SurveyFont(
                    fontFamily: "BaseFont",
                    fontColor: "#baseFont",
                    colorType: .automatic
                ),
                progress: ProgressStyle(
                    color: "#baseColor",
                    colorType: .automatic,
                    enabled: true,
                    type: .bar),
                backdrop: Backdrop(
                    color: "#baseBackdrop",
                    enabled: true,
                    opacity: 90
                )
            )
        )

        let surveyOverride = SurveyTheme(
            general: SurveyGeneral(
                position: .center,
                primaryColor: "#overridePrimary",
                backgroundColor: nil,
                cornerRadius: nil
            ),
            font: nil,
            progress: nil,
            backdrop: nil
        )

        // Act
        let merged = themeHandler.mergeSurveyThemes(baseTheme, surveyOverride)

        // Assert
        XCTAssertEqual(merged.general?.position, .center)
        XCTAssertEqual(merged.general?.primaryColor, "#overridePrimary")
        XCTAssertEqual(merged.general?.backgroundColor, "#baseBg")
        XCTAssertEqual(merged.font?.fontFamily, "BaseFont")
        XCTAssertEqual(merged.backdrop?.color, "#baseBackdrop")
    }

    func testThemeContent_decodesSuccessfully_whenJsonIsValid() throws {
        // Arrange
        let json = """
        {
            "id": 42,
            "theme_data": {
                "carousel": {
                    "button": {
                        "background_color": "#FF0000"
                    }
                }
            }
        }
        """
        let data = Data(json.utf8)

        // Act
        let result = try JSONDecoder().decode(ThemeContent.self, from: data)

        // Assert
        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(result.themeData?.carousel?.button?.backgroundColor, "#FF0000")
    }

    func testToMobileTheme_returnsThemeContent_whenJsonIsValid() {
        // Arrange
        let json = """
        {
            "id": 1,
            "theme_data": {
                "carousel": {
                    "button": {
                        "background_color": "#123456"
                    }
                }
            }
        }
        """

        // Act
        let theme = json.toMobileTheme()

        // Assert
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.id, 1)
        XCTAssertEqual(theme?.themeData?.carousel?.button?.backgroundColor, "#123456")
    }

    func testToMobileTheme_returnsNil_whenJsonIsInvalid() {
        // Arrange
        let invalidJson = "{ invalid json }"

        // Act
        let theme = invalidJson.toMobileTheme()

        // Assert
        XCTAssertNil(theme)
    }
}
