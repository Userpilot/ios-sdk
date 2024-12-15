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

    /// Merges multiple themes into a unified theme.
    func mergeThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?
    ) -> ThemeData
}

// MARK: - ThemeHandler Class

internal class ThemeHandler: ThemeHandling {

    // MARK: - Nested Types

    /// Default values for various text styles and attributes.
    struct DefaultValues {
        static let headerTextSize = 16
        static let normalTextSize = 16
        static let dimDegree = 40
        static let slideOutContentMaxHeightPercentage = 0.55
        static let blackColor = "#000000"
        static let whiteColor = "#FFFFFF"
        static let distanceBetweenSections = CGFloat(12)
        static let contentMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(20) : CGFloat(20)
        static let contentBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(30) : CGFloat(20)
        static let buttonBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(62) : CGFloat(52)
        static let carouselContentTopMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(70) : CGFloat(12)

        static let slideOutCornerRadius = CGFloat(12)
        static let blurImageSize = CGSize(width: 64, height: 64)
        static let iconImageSize = CGSize(width: iconImageDimensions, height: iconImageDimensions)
        static let defaultTextMargin = "   "
        static let imageSize = CGFloat(300)
        static let closeButtonAlpha = 0.8
        static let dismissButtonMargin = CGFloat(10)
        static let iconImageDimensions = 38
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
     Saves the given theme data into the `themes` map using the theme ID as the key.

     - Parameter themeResponse: The response containing the theme data to be saved.
     */
    func saveTheme(_ themeContent: ThemeContent) {
        if let id = themeContent.id, let themeData = themeContent.themeData {
            themes[id] = themeData
        }
    }

    /**
     Retrieves the theme data associated with the specified theme ID.

     - Parameter themeId: The ID of the theme to retrieve.
     - Returns: The theme data if found, or `nil` if no theme with the given ID is cached.
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
    func mergeThemes(
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
                        ?? baseTheme?.carousel?.progress?.enabled
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
            )
        )
    }
}
