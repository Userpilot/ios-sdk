//
//  ThemeHandler.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This class and protocol define how themes are managed within the application.
//  `ThemeHandling` provides an interface for saving, retrieving, and merging theme data.
//  `ThemeHandler` implements the protocol, handling theme caching and merging logic.
//  A host-selected app theme, fetched by title, replaces every flow and survey theme once resolved.
//

import Foundation
import UIKit

/// The theme an experience waits for: its own theme ID, or the title of the host app's theme.
internal enum ThemeKey: Equatable {
    case id(Int)
    case title(String)
}

// MARK: - ThemeHandling Protocol

internal protocol ThemeHandling: AnyObject {

    /// Saves the provided theme data.
    func saveTheme(_ themeResponse: ThemeContent)

    /// Retrieves theme data for the specified theme ID.
    func getThemeById(_ themeId: Int) -> ThemeData?

    /// The resolved host app theme. While set, it replaces the base, content and step themes.
    var appTheme: ThemeData? { get }

    /// Selects the host app theme by title; nil restores per-experience themes.
    func setAppTheme(name: String?)

    /// The theme `content` still needs before display, or nil when it can render now.
    func requiredThemeKey(for content: ExperienceContent) -> ThemeKey?

    /// Caches a reply to an app theme request. Returns false when it lacks data or names another title.
    func saveAppTheme(_ themeContent: ThemeContent, title: String) -> Bool

    /// Stops requesting `title` until the next connection; experiences use their own themes meanwhile.
    func markAppThemeUnavailable(_ title: String)

    /// Forgets fetched app themes and unavailable titles so the next experience fetches them again.
    func resetAppThemes()

    /// Drops the selected title, the resolved theme and every cached app theme; experiences use their own themes.
    func clearAppTheme()

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

extension ThemeHandling {

    /// One theme per step. A resolved app theme replaces the content's base, flow and step themes,
    /// including placement, which the app theme carries in `general`.
    func flowThemes(for content: FlowContent) -> [ThemeData] {
        if let appTheme {
            let theme = mergeExperienceThemes(appTheme, nil, nil)
            return content.steps.map { _ in theme }
        }
        let baseTheme = getThemeById(content.baseThemeId)
        return content.steps.map { step in
            mergeExperienceThemes(baseTheme, content.mobileTheme.themeData, step.mobileTheme)
        }
    }

    /// A resolved app theme replaces the survey's base and embedded themes, including its position.
    func surveyTheme(for content: SurveyContent) -> SurveyTheme {
        if let appTheme {
            return mergeSurveyThemes(appTheme, nil)
        }
        return mergeSurveyThemes(getThemeById(content.baseThemeId), content.surveyTheme.themeData)
    }
}

// MARK: - ThemeHandler Class

internal class ThemeHandler: ThemeHandling {

    // MARK: - Nested Types

    /// Default values for various text styles and attributes.
    enum DefaultValues {
        // Carousels & Slide out
        static let delayTimeForExperience = 0.5
        static let delayTimeForDeepLink = 0.3
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
        static let contentTopMargin = CGFloat(10)
        static let contentBottomMargin = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(30) : CGFloat(20)
        static let buttonBottomMarginWithStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(62) : CGFloat(52)
        static let buttonBottomMarginWithoutStepProgress = UIDevice.current.userInterfaceIdiom == .pad
        ? CGFloat(35) : CGFloat(25)
        static let carouselContentTopMargin = CGFloat(65)

        static let slideOutCornerRadius = CGFloat(12)
        static let blurImageSize = CGSize(width: 64, height: 64)
        static let iconImageSize = CGSize(width: iconImageDimensions, height: iconImageDimensions)
        static let defaultTextMargin = "   "
        static let imageSize = CGFloat(300)
        static let closeButtonAlpha = 0.8
        static let dismissButtonMargin = CGFloat(10)
        /// The height of `UPStepsBarProgressView`. Its layers are fully rounded,
        /// so this also drives their corner radius.
        static let stepsProgressBarHeight = CGFloat(5)
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

        /// NPS header layout: the steps progress bar sits at the very top of the sheet and the dismiss
        /// button hangs below its container, so the button needs a margin to clear the bar.
        static let npsProgressBarTopInset = CGFloat(20)
        static let npsDismissButtonTopMargin = CGFloat(8)
        static let npsDismissButtonBottomOverhang = CGFloat(10)

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
    enum StyleName {
        static let textStyle = "textStyle"
        static let textLink = "link"
        static let textBold = "bold"
        static let textItalic = "italic"
    }

    /// Additional style values.
    enum StyleValues {
        static let manual = "manual"
        static let borderRadius = 0
    }

    // MARK: - Properties

    /// Publisher preparation and view models share this instance cache across their own queues.
    private let cacheLock = NSLock()
    private var themes: [Int: ThemeData] = [:]
    private var appThemeName: String?
    private var appThemes: [String: ThemeData] = [:]
    private var unavailableAppThemes: Set<String> = []
    /// Keeps the previous app theme while a newly selected title is still being fetched.
    private var resolvedAppTheme: ThemeData?

    // MARK: - ThemeHandling Implementation

    /// A response without both an ID and data leaves any previously cached theme intact.
    func saveTheme(_ themeContent: ThemeContent) {
        guard let id = themeContent.id, let themeData = themeContent.themeData else { return }
        cacheLock.withLock { themes[id] = themeData }
    }

    /// Returns the instance's cached theme without changing its lifetime or applying defaults.
    func getThemeById(_ themeId: Int) -> ThemeData? {
        cacheLock.withLock { themes[themeId] }
    }

    var appTheme: ThemeData? {
        cacheLock.withLock { resolvedAppTheme }
    }

    func setAppTheme(name: String?) {
        cacheLock.withLock {
            appThemeName = name
            guard let name else {
                resolvedAppTheme = nil
                return
            }
            if let cached = appThemes[name] {
                resolvedAppTheme = cached
            } else if unavailableAppThemes.contains(name) {
                resolvedAppTheme = nil
            }
        }
    }

    /// NPS embeds its theme. A selected, available app theme is required instead of the content's own.
    func requiredThemeKey(for content: ExperienceContent) -> ThemeKey? {
        guard content.asNPSContent() == nil else { return nil }
        let themeId = content.experienceThemeId()
        return cacheLock.withLock {
            if let name = appThemeName, !unavailableAppThemes.contains(name) {
                return appThemes[name] == nil ? .title(name) : nil
            }
            return themes[themeId] == nil ? .id(themeId) : nil
        }
    }

    func saveAppTheme(_ themeContent: ThemeContent, title: String) -> Bool {
        guard themeContent.title == title, let themeData = themeContent.themeData else { return false }
        cacheLock.withLock {
            appThemes[title] = themeData
            unavailableAppThemes.remove(title)
            if appThemeName == title { resolvedAppTheme = themeData }
        }
        return true
    }

    func markAppThemeUnavailable(_ title: String) {
        cacheLock.withLock {
            unavailableAppThemes.insert(title)
            if appThemeName == title { resolvedAppTheme = nil }
        }
    }

    /// The resolved theme stays in use until its refetch replies, so rendering never loses it.
    func resetAppThemes() {
        cacheLock.withLock {
            appThemes.removeAll()
            unavailableAppThemes.removeAll()
        }
    }

    func clearAppTheme() {
        cacheLock.withLock {
            appThemeName = nil
            resolvedAppTheme = nil
            appThemes.removeAll()
            unavailableAppThemes.removeAll()
        }
    }

    /// Resolves each field as step → global → base; each flow keeps only its supported styles.
    func mergeExperienceThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?
    ) -> ThemeData {
        var carousel = (baseTheme?.carousel).merging(globalTheme: globalTheme, stepTheme: stepTheme)
        var slideOut = (baseTheme?.slideOut).merging(globalTheme: globalTheme, stepTheme: stepTheme)
        carousel.backdrop = nil
        slideOut.progress = nil
        return ThemeData(carousel: carousel, slideOut: slideOut, survey: nil)
    }

    /// Resolves each survey field against its base without changing either source theme.
    func mergeSurveyThemes(
        _ baseTheme: ThemeData?,
        _ surveyTheme: SurveyTheme?
    ) -> SurveyTheme {
        (baseTheme?.survey).merging(surveyTheme)
    }
}
