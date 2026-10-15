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

// MARK: - ThemeHandling Protocol

internal protocol ThemeHandling: AnyObject {

    /// Saves the provided theme data.
    func saveTheme(_ themeResponse: ThemeContent)

    /// Retrieves theme data for the specified theme ID.
    func getThemeById(_ themeId: Int) -> ThemeData?

    /// The resolved host app theme. While set, it replaces the base, content and step themes.
    var appTheme: ThemeData? { get }

    /// Persists the host app theme title; use clearAppTheme to restore per-experience themes.
    func setAppTheme(name: String)

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

    // MARK: - Properties

    /// Publisher preparation and view models share this instance cache across their own queues.
    private let cacheLock = NSLock()
    private let storage: DataStoring
    private var themes: [Int: ThemeData] = [:]
    private var appThemes: [String: ThemeData] = [:]
    private var unavailableAppThemes: Set<String> = []
    /// Keeps the previous app theme while a newly selected title is still being fetched.
    private var resolvedAppTheme: ThemeData?

    init(container: DIContainer) {
        storage = container.resolve(DataStoring.self)
    }

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

    func setAppTheme(name: String) {
        cacheLock.withLock {
            storage.appThemeName = name
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
            // Read the persisted selection when content needs it; fetched styles stay in memory.
            if let name = storage.appThemeName, !unavailableAppThemes.contains(name) {
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
            if storage.appThemeName == title { resolvedAppTheme = themeData }
        }
        return true
    }

    func markAppThemeUnavailable(_ title: String) {
        cacheLock.withLock {
            unavailableAppThemes.insert(title)
            if storage.appThemeName == title { resolvedAppTheme = nil }
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
            storage.appThemeName = nil
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
