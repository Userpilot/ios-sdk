//
//  ThemeContentMerging.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves the theme for each flow step and survey using the selected app theme when available.
//

extension ThemeHandling {

    /// One theme per step. A resolved app theme replaces the content's base, flow and step themes,
    /// including placement, which the app theme carries in `general`. A Flow segment's steps merge
    /// through `mergeFlowStepThemes`.
    ///
    /// - Parameters:
    ///   - content: The content whose steps each need a theme.
    ///   - isFlowSegment: True for one segment of a Flow walk; false keeps the standalone carousel/slideout merge.
    func flowThemes(for content: FlowContent, isFlowSegment: Bool = false) -> [ThemeData] {
        isFlowSegment ? flowStepThemes(for: content) : experienceThemes(for: content)
    }

    /// The standalone carousel and slideout merge: the app theme for every step when resolved, else the base,
    /// content and step themes.
    private func experienceThemes(for content: FlowContent) -> [ThemeData] {
        if let appTheme {
            let theme = mergeExperienceThemes(appTheme, nil, nil)
            return content.steps.map { _ in theme }
        }
        let baseTheme = getThemeById(content.baseThemeId)
        return content.steps.map { step in
            mergeExperienceThemes(baseTheme, content.mobileTheme.themeData, step.mobileTheme)
        }
    }

    /// A resolved app theme replaces the base, custom and step styling, but never a step's `settings.backdrop`.
    private func flowStepThemes(for content: FlowContent) -> [ThemeData] {
        let resolved = appTheme
        let baseTheme = resolved ?? getThemeById(content.baseThemeId)
        let contentTheme = resolved == nil ? content.mobileTheme.themeData : nil
        return content.steps.map { step in
            mergeFlowStepThemes(
                baseTheme: baseTheme,
                contentTheme: contentTheme,
                stepTheme: resolved == nil ? step.mobileTheme : nil,
                stepBackdrop: step.settings?.backdrop
            )
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
