//
//  ThemeHandler.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
    /// - Parameter themeResponse: The response containing the theme data to be saved.
    func saveTheme(_ themeResponse: ThemeContent)

    /// Retrieves theme data for the specified theme ID.
    /// - Parameter themeId: The ID of the theme to retrieve.
    /// - Returns: The theme data if found, otherwise `nil`.
    func getThemeById(_ themeId: Int, _ type: ContentType) -> ThemeData?

    /// Checks if the specified theme ID is already cached.
    /// - Parameter themeId: The ID of the theme to check.
    /// - Returns: `true` if the theme ID is cached, `false` otherwise.
    func containsTheme(_ themeId: Int, _ type: ContentType) -> Bool

    /// Merges multiple themes into a unified theme.
    /// - Parameters:
    ///   - baseTheme: The base theme data.
    ///   - globalTheme: The global theme data.
    ///   - stepTheme: The step-specific theme data.
    /// - Returns: A unified theme that combines all provided themes.
    func mergeThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ThemeData?,
        _ stepTheme: ThemeData?
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
        static let contentMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(70) : CGFloat(20)
        static let contentBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(30) : CGFloat(20)
        static let slideOutCornerRadius = CGFloat(20)

        /// Default text style mark with predefined attributes.
        static var defaultTextStyleMark: Mark {
            return Mark(
                type: StyleName.textStyle,
                attrs: MarkAttributes(
                    fontSize: Int(normalTextSize),
                    href: nil,
                    color: blackColor
                )
            )
        }
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
    private var carouselThemes: [Int: ThemeData] = [:]
    private var slideOutThemes: [Int: ThemeData] = [:]

    // MARK: - ThemeHandling Implementation

    /**
     Saves the given theme data into the `themes` map using the theme ID as the key.

     - Parameter themeResponse: The response containing the theme data to be saved.
     */
    func saveTheme(_ themeContent: ThemeContent) {
        if let id = themeContent.id, let themeData = themeContent.themeData {
            if themeContent.themeData?.carousel != nil {
                carouselThemes[id] = themeData
            } else if themeContent.themeData?.slideOut != nil {
                slideOutThemes[id] = themeData
            }
        }
    }

    /**
     Retrieves the theme data associated with the specified theme ID.

     - Parameter themeId: The ID of the theme to retrieve.
     - Returns: The theme data if found, or `nil` if no theme with the given ID is cached.
     */
    func getThemeById(_ themeId: Int, _ type: ContentType) -> ThemeData? {
        if type == .carousel {
            return carouselThemes[themeId]
        } else {
            return slideOutThemes[themeId]
        }
    }

    /**
     Checks if the provided set of theme IDs is fully contained within the cached themes.

     - Parameter themeId: The set of theme IDs to check.
     - Returns: `true` if the theme ID is cached, `false` otherwise.
     */
    func containsTheme(_ themeId: Int, _ type: ContentType) -> Bool {
        if type == .carousel {
            return carouselThemes.keys.contains(themeId)
        } else {
            return slideOutThemes.keys.contains(themeId)
        }
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
        _ globalTheme: ThemeData?,
        _ stepTheme: ThemeData?
    ) -> ThemeData {
        return ThemeData(
            carousel: ExperienceTheme(
                button: ButtonStyle(
                    backgroundColor: stepTheme?.carousel?.button?.backgroundColor
                        ?? globalTheme?.carousel?.button?.backgroundColor
                        ?? baseTheme?.carousel?.button?.backgroundColor,
                    labelColor: stepTheme?.carousel?.button?.labelColor
                        ?? globalTheme?.carousel?.button?.labelColor
                        ?? baseTheme?.carousel?.button?.labelColor,
                    borderColor: stepTheme?.carousel?.button?.borderColor
                        ?? globalTheme?.carousel?.button?.borderColor
                        ?? baseTheme?.carousel?.button?.borderColor,
                    borderWidth: stepTheme?.carousel?.button?.borderWidth
                        ?? globalTheme?.carousel?.button?.borderWidth
                        ?? baseTheme?.carousel?.button?.borderWidth,
                    borderRadius: stepTheme?.carousel?.button?.borderRadius
                        ?? globalTheme?.carousel?.button?.borderRadius
                        ?? baseTheme?.carousel?.button?.borderRadius
                ),
                colors: ColorsStyle(
                    backgroundColor: stepTheme?.carousel?.colors?.backgroundColor
                        ?? globalTheme?.carousel?.colors?.backgroundColor
                        ?? baseTheme?.carousel?.colors?.backgroundColor,
                    textColor: stepTheme?.carousel?.colors?.textColor
                        ?? globalTheme?.carousel?.colors?.textColor
                        ?? baseTheme?.carousel?.colors?.textColor,
                    titleColor: stepTheme?.carousel?.colors?.titleColor
                        ?? globalTheme?.carousel?.colors?.titleColor
                        ?? baseTheme?.carousel?.colors?.titleColor
                ),
                dismissContent: DismissContentStyle(
                    color: stepTheme?.carousel?.dismissContent?.color
                        ?? globalTheme?.carousel?.dismissContent?.color
                        ?? baseTheme?.carousel?.dismissContent?.color,
                    colorType: stepTheme?.carousel?.dismissContent?.colorType
                        ?? globalTheme?.carousel?.dismissContent?.colorType
                        ?? baseTheme?.carousel?.dismissContent?.colorType,
                    enabled: stepTheme?.carousel?.dismissContent?.enabled
                        ?? globalTheme?.carousel?.dismissContent?.enabled
                        ?? baseTheme?.carousel?.dismissContent?.enabled
                ),
                general: GeneralStyle(
                    contentAlignment: stepTheme?.carousel?.general?.contentAlignment
                        ?? globalTheme?.carousel?.general?.contentAlignment
                        ?? baseTheme?.carousel?.general?.contentAlignment,
                    fontFamily: stepTheme?.carousel?.general?.fontFamily
                        ?? globalTheme?.carousel?.general?.fontFamily
                        ?? baseTheme?.carousel?.general?.fontFamily
                ),
                progress: ProgressStyle(
                    color: stepTheme?.carousel?.progress?.color
                        ?? globalTheme?.carousel?.progress?.color
                        ?? baseTheme?.carousel?.progress?.color,
                    colorType: stepTheme?.carousel?.progress?.colorType
                        ?? globalTheme?.carousel?.progress?.colorType
                        ?? baseTheme?.carousel?.progress?.colorType,
                    enabled: stepTheme?.carousel?.progress?.enabled
                        ?? globalTheme?.carousel?.progress?.enabled
                        ?? baseTheme?.carousel?.progress?.enabled
                )
            ),
            slideOut: ExperienceTheme(
                button: ButtonStyle(
                    backgroundColor: stepTheme?.slideOut?.button?.backgroundColor
                        ?? globalTheme?.slideOut?.button?.backgroundColor
                        ?? baseTheme?.slideOut?.button?.backgroundColor,
                    labelColor: stepTheme?.slideOut?.button?.labelColor
                        ?? globalTheme?.slideOut?.button?.labelColor
                        ?? baseTheme?.slideOut?.button?.labelColor,
                    borderColor: stepTheme?.slideOut?.button?.borderColor
                        ?? globalTheme?.slideOut?.button?.borderColor
                        ?? baseTheme?.slideOut?.button?.borderColor,
                    borderWidth: stepTheme?.slideOut?.button?.borderWidth
                        ?? globalTheme?.slideOut?.button?.borderWidth
                        ?? baseTheme?.slideOut?.button?.borderWidth,
                    borderRadius: stepTheme?.slideOut?.button?.borderRadius
                        ?? globalTheme?.slideOut?.button?.borderRadius
                        ?? baseTheme?.slideOut?.button?.borderRadius
                ),
                colors: ColorsStyle(
                    backgroundColor: stepTheme?.slideOut?.colors?.backgroundColor
                        ?? globalTheme?.slideOut?.colors?.backgroundColor
                        ?? baseTheme?.slideOut?.colors?.backgroundColor,
                    textColor: stepTheme?.slideOut?.colors?.textColor
                        ?? globalTheme?.slideOut?.colors?.textColor
                        ?? baseTheme?.slideOut?.colors?.textColor,
                    titleColor: stepTheme?.slideOut?.colors?.titleColor
                        ?? globalTheme?.slideOut?.colors?.titleColor
                        ?? baseTheme?.slideOut?.colors?.titleColor
                ),
                dismissContent: DismissContentStyle(
                    color: stepTheme?.slideOut?.dismissContent?.color
                        ?? globalTheme?.slideOut?.dismissContent?.color
                        ?? baseTheme?.slideOut?.dismissContent?.color,
                    colorType: stepTheme?.slideOut?.dismissContent?.colorType
                        ?? globalTheme?.slideOut?.dismissContent?.colorType
                        ?? baseTheme?.slideOut?.dismissContent?.colorType,
                    enabled: stepTheme?.slideOut?.dismissContent?.enabled
                        ?? globalTheme?.slideOut?.dismissContent?.enabled
                        ?? baseTheme?.slideOut?.dismissContent?.enabled
                ),
                general: GeneralStyle(
                    contentAlignment: stepTheme?.slideOut?.general?.contentAlignment
                        ?? globalTheme?.slideOut?.general?.contentAlignment
                        ?? baseTheme?.slideOut?.general?.contentAlignment,
                    fontFamily: stepTheme?.slideOut?.general?.fontFamily
                        ?? globalTheme?.slideOut?.general?.fontFamily
                        ?? baseTheme?.slideOut?.general?.fontFamily
                ),
                backdrop: Backdrop(
                    color: stepTheme?.slideOut?.backdrop?.color
                        ?? globalTheme?.slideOut?.backdrop?.color
                        ?? baseTheme?.slideOut?.backdrop?.color,
                    enabled: stepTheme?.slideOut?.backdrop?.enabled
                        ?? globalTheme?.slideOut?.backdrop?.enabled
                        ?? baseTheme?.slideOut?.backdrop?.enabled,
                    opacity: stepTheme?.slideOut?.backdrop?.opacity
                    ?? globalTheme?.slideOut?.backdrop?.opacity
                    ?? baseTheme?.slideOut?.backdrop?.opacity
                )
            )
        )
    }
}
