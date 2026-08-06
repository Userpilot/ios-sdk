//
//  ThemeHandler.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This class and protocol define how themes are managed within the application.
//  `ThemeHandling` provides an interface for saving, retrieving, and merging theme data.
//  `ThemeHandler` implements the protocol, handling theme caching and merging logic.
//

import Foundation
import UIKit

// MARK: - ThemeHandling Protocol

internal protocol ThemeHandling: AnyObject {

    /// Saves the provided theme data.
    func saveTheme(_ themeResponse: ThemeContent)

    /// Retrieves theme data for the specified theme ID.
    func getThemeById(_ themeId: Int) -> ThemeData?

    /// Merges Experience themes into a unified theme.
    func mergeExperienceThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?
    ) -> ThemeData

    /// Merges Survey themes into a unified theme.
    func mergeSurveyThemes(
        _ baseTheme: ThemeData?,
        _ surveyTheme: SurveyTheme?
    ) -> SurveyTheme
}

// MARK: - ThemeHandler Class

// swiftlint:disable:next type_body_length
internal class ThemeHandler: ThemeHandling {

    // MARK: - Nested Types

    /// Default values for various text styles and attributes.
    struct DefaultValues {
        // Carousels & Slide out
        static let delayTimeForExperience = 0.5
        static let delayTimeForDeepLink = 0.5
        static let headerTextSize = 16
        static let normalTextSize = 16
        static let dimSlideOutDegree = 40
        static var slideOutContentMaxHeightPercentage: CGFloat {
            if isLandscape {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    return CGFloat(0.65)
                } else {
                    return CGFloat(0.4)
                }
            } else {
                return CGFloat(0.55)
            }
        }
        static var leftRightMargin: CGFloat {
            if isLandscape {
                return CGFloat(70)
            } else {
                return 0
            }
        }
        static let blackColor = "#000000"
        static let whiteColor = "#FFFFFF"
        static let grayColor = "#ACB5BD".color
        static let distanceBetweenSections = CGFloat(12)
        static let smallDistanceBetweenSections = CGFloat(8)
        static let contentMargin = CGFloat(20)
        static let contentBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(30) : CGFloat(20)
        static let buttonBottomMarginWithStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(62) : CGFloat(52)
        static let buttonBottomMarginWithoutStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(35) : CGFloat(25)
        static let carouselContentTopMargin = CGFloat(55)

        static let slideOutCornerRadius = CGFloat(12)
        static let blurImageSize = CGSize(width: 64, height: 64)
        static let iconImageSize = CGSize(width: iconImageDimensions, height: iconImageDimensions)
        static let defaultTextMargin = "   "
        static let imageSize = CGFloat(300)
        static let closeButtonAlpha = 0.8
        static let dismissButtonMargin = CGFloat(10)
        static let iconImageDimensions = 38
        static let npsImageDimensions = 100

        /// NPS dismiss (close) button chip styling.
        /// The chip is a translucent overlay on top of the NPS background: it darkens that background —
        /// more softly on near white backgrounds (brightness above 85%), where a light gray chip is enough
        /// — and lightens it instead when the background is already too dark to be darkened further
        /// (brightness below 25%). The title color follows the color the chip resolves to.
        static let npsDismissButtonDarkenOpacity = CGFloat(0.35)
        static let npsDismissButtonSoftDarkenOpacity = CGFloat(0.16)
        static let npsDismissButtonLightenOpacity = CGFloat(0.15)
        static let npsDismissLightBackgroundBrightness = CGFloat(0.85)
        static let npsDismissDarkBackgroundBrightness = CGFloat(0.25)
        static let npsDismissButtonHeight = CGFloat(34)
        static let npsDismissButtonTextSize = CGFloat(14)

        /// Survey
        static let surveyItemRatingMinWidth: Int = 80
        static let surveyContentTopMargin: Int = 16
        static let surveyTitleTextSize: CGFloat = 16
        static let surveyDescriptionTextSize: CGFloat = 13
        static let surveyHighLowTextSize: CGFloat = 12
        static let surveyPromptButtonTextSize: CGFloat = 12
        static let surveyDescriptionTextTopMargin: Int = 10
        static let surveyDefaultLikertViewCount: Int = 10
        static let npsDefaultLikertViewCount: Int = 11
        static let surveyMaxTextFieldCharCount: Int = 500
        static let surveyPromptViewButtonMargin: Int = 50
        static let surveyContentTopMargin24: Int = 24
        static let surveyLikertViewMaxCount: Int = 10
        static let surveyOpenTextEditTextHeight: Int = 80
        static let surveyTextSize = 14

        static let surveySingleTextDefaultCountryCode: String = "+1"
        static let surveySingleTextMaxLength: Int = 50
        static let surveyOtherChoice: String = "other"
        static let surveyOtherChoiceTag = 101
    }

    /// Style names used for text formatting in themes.
    struct StyleName {
        static let textStyle = "textStyle"
        static let textLink = "link"
        static let textBold = "bold"
        static let textItalic = "italic"
    }

    /// Additional style values.
    struct StyleValues {
        static let manual = "manual"
        static let borderRadius = 0
    }

    // MARK: - Properties

    /// Cached theme data mapped by their IDs.
    private var themes: [Int: ThemeData] = [:]

    // MARK: - ThemeHandling Implementation

    /**
     Saves the given theme data into the `themes` map using the theme Id as the key.

     - Parameter themeResponse: The response containing the theme data to be saved.
     */
    func saveTheme(_ themeContent: ThemeContent) {
        if let id = themeContent.id, let themeData = themeContent.themeData {
            themes[id] = themeData
        }
    }

    /**
     Retrieves the theme data associated with the specified theme ID.

     - Parameter themeId: The Id of the theme to retrieve.
     - Returns: The theme data if found, or `nil` if no theme with the given Id is cached.
     */
    func getThemeById(_ themeId: Int) -> ThemeData? {
        return themes[themeId]
    }

    /*
     * Merges multiple theme data sources (base, global, and step-specific themes) to create a final unified theme.
     *
     * This method resolves conflicts between theme layers, prioritizing values in the order of:
     * step theme -> global theme -> base theme.
     *
     * - Parameters:
     *   - baseTheme: The base theme data.
     *   - globalTheme: The global theme data that applies to the entire experience.
     *   - stepTheme: The step-specific theme data that applies to the current step.
     * - Returns: A unified theme that combines values from all provided theme layers.
     */
    // swiftlint:disable:next function_body_length
    func mergeExperienceThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?
    ) -> ThemeData {
        return ThemeData(
            carousel: ExperienceTheme(
                button: ButtonStyle(
                    backgroundColor: stepTheme?.button?.backgroundColor
                        ?? globalTheme?.button?.backgroundColor
                        ?? baseTheme?.carousel?.button?.backgroundColor,
                    labelColor: stepTheme?.button?.labelColor
                        ?? globalTheme?.button?.labelColor
                        ?? baseTheme?.carousel?.button?.labelColor,
                    borderColor: stepTheme?.button?.borderColor
                        ?? globalTheme?.button?.borderColor
                        ?? baseTheme?.carousel?.button?.borderColor,
                    borderWidth: stepTheme?.button?.borderWidth
                        ?? globalTheme?.button?.borderWidth
                        ?? baseTheme?.carousel?.button?.borderWidth,
                    borderRadius: stepTheme?.button?.borderRadius
                        ?? globalTheme?.button?.borderRadius
                        ?? baseTheme?.carousel?.button?.borderRadius
                ),
                colors: ColorsStyle(
                    backgroundColor: stepTheme?.colors?.backgroundColor
                        ?? globalTheme?.colors?.backgroundColor
                        ?? baseTheme?.carousel?.colors?.backgroundColor,
                    textColor: stepTheme?.colors?.textColor
                        ?? globalTheme?.colors?.textColor
                        ?? baseTheme?.carousel?.colors?.textColor,
                    titleColor: stepTheme?.colors?.titleColor
                        ?? globalTheme?.colors?.titleColor
                        ?? baseTheme?.carousel?.colors?.titleColor
                ),
                dismissContent: DismissContentStyle(
                    color: stepTheme?.dismissContent?.color
                        ?? globalTheme?.dismissContent?.color
                        ?? baseTheme?.carousel?.dismissContent?.color,
                    colorType: stepTheme?.dismissContent?.colorType
                        ?? globalTheme?.dismissContent?.colorType
                        ?? baseTheme?.carousel?.dismissContent?.colorType,
                    enabled: stepTheme?.dismissContent?.enabled
                        ?? globalTheme?.dismissContent?.enabled
                        ?? baseTheme?.carousel?.dismissContent?.enabled
                ),
                general: GeneralStyle(
                    contentAlignment: stepTheme?.general?.contentAlignment
                        ?? globalTheme?.general?.contentAlignment
                        ?? baseTheme?.carousel?.general?.contentAlignment,
                    fontFamily: stepTheme?.general?.fontFamily
                        ?? globalTheme?.general?.fontFamily
                        ?? baseTheme?.carousel?.general?.fontFamily
                ),
                progress: ProgressStyle(
                    color: stepTheme?.progress?.color
                        ?? globalTheme?.progress?.color
                        ?? baseTheme?.carousel?.progress?.color,
                    colorType: stepTheme?.progress?.colorType
                        ?? globalTheme?.progress?.colorType
                        ?? baseTheme?.carousel?.progress?.colorType,
                    enabled: stepTheme?.progress?.enabled
                        ?? globalTheme?.progress?.enabled
                        ?? baseTheme?.carousel?.progress?.enabled,
                    type: stepTheme?.progress?.type
                        ?? globalTheme?.progress?.type
                        ?? baseTheme?.carousel?.progress?.type
                )
            ),
            slideOut: ExperienceTheme(
                button: ButtonStyle(
                    backgroundColor: stepTheme?.button?.backgroundColor
                        ?? globalTheme?.button?.backgroundColor
                        ?? baseTheme?.slideOut?.button?.backgroundColor,
                    labelColor: stepTheme?.button?.labelColor
                        ?? globalTheme?.button?.labelColor
                        ?? baseTheme?.slideOut?.button?.labelColor,
                    borderColor: stepTheme?.button?.borderColor
                        ?? globalTheme?.button?.borderColor
                        ?? baseTheme?.slideOut?.button?.borderColor,
                    borderWidth: stepTheme?.button?.borderWidth
                        ?? globalTheme?.button?.borderWidth
                        ?? baseTheme?.slideOut?.button?.borderWidth,
                    borderRadius: stepTheme?.button?.borderRadius
                        ?? globalTheme?.button?.borderRadius
                        ?? baseTheme?.slideOut?.button?.borderRadius
                ),
                colors: ColorsStyle(
                    backgroundColor: stepTheme?.colors?.backgroundColor
                        ?? globalTheme?.colors?.backgroundColor
                        ?? baseTheme?.slideOut?.colors?.backgroundColor,
                    textColor: stepTheme?.colors?.textColor
                        ?? globalTheme?.colors?.textColor
                        ?? baseTheme?.slideOut?.colors?.textColor,
                    titleColor: stepTheme?.colors?.titleColor
                        ?? globalTheme?.colors?.titleColor
                        ?? baseTheme?.slideOut?.colors?.titleColor
                ),
                dismissContent: DismissContentStyle(
                    color: stepTheme?.dismissContent?.color
                        ?? globalTheme?.dismissContent?.color
                        ?? baseTheme?.slideOut?.dismissContent?.color,
                    colorType: stepTheme?.dismissContent?.colorType
                        ?? globalTheme?.dismissContent?.colorType
                        ?? baseTheme?.slideOut?.dismissContent?.colorType,
                    enabled: stepTheme?.dismissContent?.enabled
                        ?? globalTheme?.dismissContent?.enabled
                        ?? baseTheme?.slideOut?.dismissContent?.enabled
                ),
                general: GeneralStyle(
                    contentAlignment: stepTheme?.general?.contentAlignment
                        ?? globalTheme?.general?.contentAlignment
                        ?? baseTheme?.slideOut?.general?.contentAlignment,
                    fontFamily: stepTheme?.general?.fontFamily
                        ?? globalTheme?.general?.fontFamily
                        ?? baseTheme?.slideOut?.general?.fontFamily
                ),
                backdrop: Backdrop(
                    color: stepTheme?.backdrop?.color
                        ?? globalTheme?.backdrop?.color
                        ?? baseTheme?.slideOut?.backdrop?.color,
                    enabled: stepTheme?.backdrop?.enabled
                        ?? globalTheme?.backdrop?.enabled
                        ?? baseTheme?.slideOut?.backdrop?.enabled,
                    opacity: stepTheme?.backdrop?.opacity
                    ?? globalTheme?.backdrop?.opacity
                    ?? baseTheme?.slideOut?.backdrop?.opacity
                )
            ),
            survey: nil
        )
    }

    /*
     * Merges Survey themes (base, global) to create a final unified theme.
     *
     * - Parameters:
     *   - baseTheme: The base theme data.
     *   - surveyTheme: The global theme data that applies to the entire survey.
     * - Returns: A unified theme that combines values from all provided theme layers.
     */
    func mergeSurveyThemes(
        _ baseTheme: ThemeData?,
        _ surveyTheme: SurveyTheme?
    ) -> SurveyTheme {
        return SurveyTheme(
            general: SurveyGeneral(
                position: surveyTheme?.general?.position
                    ?? baseTheme?.survey?.general?.position,
                primaryColor: surveyTheme?.general?.primaryColor
                    ?? baseTheme?.survey?.general?.primaryColor,
                backgroundColor: surveyTheme?.general?.backgroundColor
                    ?? baseTheme?.survey?.general?.backgroundColor,
                cornerRadius: surveyTheme?.general?.cornerRadius
                    ?? baseTheme?.survey?.general?.cornerRadius
            ),
            font: SurveyFont(
                fontFamily: surveyTheme?.font?.fontFamily
                    ?? baseTheme?.survey?.font?.fontFamily,
                fontColor: surveyTheme?.font?.fontColor
                    ?? baseTheme?.survey?.font?.fontColor,
                colorType: surveyTheme?.font?.colorType
                    ?? baseTheme?.survey?.font?.colorType
            ),
            progress: ProgressStyle(
                color: surveyTheme?.progress?.color
                    ?? baseTheme?.survey?.progress?.color,
                colorType: surveyTheme?.progress?.colorType
                    ?? baseTheme?.survey?.progress?.colorType,
                enabled: surveyTheme?.progress?.enabled
                    ?? baseTheme?.survey?.progress?.enabled,
                type: surveyTheme?.progress?.type
                    ?? baseTheme?.survey?.progress?.type
            ),
            backdrop: Backdrop(
                color: surveyTheme?.backdrop?.color
                    ?? baseTheme?.survey?.backdrop?.color,
                enabled: surveyTheme?.backdrop?.enabled
                    ?? baseTheme?.survey?.backdrop?.enabled,
                opacity: surveyTheme?.backdrop?.opacity
                    ?? baseTheme?.survey?.backdrop?.opacity
            )
        )
    }
}
