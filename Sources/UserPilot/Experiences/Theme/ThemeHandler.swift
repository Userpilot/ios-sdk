//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation

internal protocol ThemeHandling: AnyObject {
    func saveTheme(_ themeResponse: ThemeResponse)
    func getThemeById(_ themeId: Int) -> ThemeData?
    func containsTheme(_ themeId: Int) -> Bool

    func mergeThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ThemeData?,
        _ stepTheme: ThemeData?
    ) -> ThemeData
}

internal class ThemeHandler: ThemeHandling {

    /// Object that defines default values for various text styles and attributes used in themes.
    struct DefaultValues {
        static let headerTextSize = 16
        static let normalTextSize = 14
        static let blackColor = "#000000"

        /// Returns the default text style mark with predefined attributes.
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

    /// Object that defines various style names used for text formatting in the themes.
    struct StyleName {
        static let textStyle = "textStyle"
        static let textLink = "link"
        static let textBold = "bold"
        static let textItalic = "italic"
    }

    struct StyleValues {
        static let manual = "manual"
        static let borderRadius = 8
    }

    // Stores theme data mapped by their IDs.
    private var themes: [Int: ThemeData] = [:]

    /**
     * Saves the given theme data into the `themes` map using the theme ID as the key.
     *
     * - Parameter themeResponse: The response containing the theme data to be saved.
     */
    func saveTheme(_ themeResponse: ThemeResponse) {
        if let id = themeResponse.mobileTheme?.id {
            themes[id] = themeResponse.mobileTheme?.themeData
        }
    }

    /**
     * Retrieves the theme data associated with the specified theme ID.
     *
     * - Parameter themeId: The ID of the theme to retrieve.
     * - Returns: The theme data if found, or `nil` if no theme with the given ID is cached.
     */
    func getThemeById(_ themeId: Int) -> ThemeData? {
        return themes[themeId]
    }

    /**
     * Checks if the provided set of theme IDs is fully contained within the cached themes.
     *
     * - Parameter themeId: The set of theme IDs to check.
     * - Returns: `true` if the theme ID is cached, `false` otherwise.
     */
    func containsTheme(_ themeId: Int) -> Bool {
        return themes.keys.contains(themeId)
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
            carousel: CarouselTheme(
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
            )
        )
    }
}
