//
//  ExperienceContent.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2021 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Represents the ExperienceContent like FlowContent & SurveyContent.
//

// Enum that encapsulates different types of experience content: FlowContent and SurveyContent.
internal enum ExperienceContent {
    case flow(content: FlowContent)   // Represents a flow content.
    case survey(content: SurveyContent) // Represents a survey content.
    case nps(content: NPSContent) // Represents a survey content.
}

// Extensions for ExperienceContent to provide access to content and other properties.

extension ExperienceContent {

    /// Safely retrieves the FlowContent if the current instance is of type .flow.
    /// - Returns: The FlowContent associated with this enum case, or nil if it's not of type flow.
    func asFlowContent() -> FlowContent? {
        if case let .flow(content) = self {
            return content
        }
        return nil
    }

    /// Safely retrieves the SurveyContent if the current instance is of type .survey.
    /// - Returns: The SurveyContent associated with this enum case, or nil if it's not of type survey.
    func asSurveyContent() -> SurveyContent? {
        if case let .survey(content) = self {
            return content
        }
        return nil
    }

    /// Safely retrieves the NPSContent if the current instance is of type .survey.
    /// - Returns: The NPSContent associated with this enum case, or nil if it's not of type nps.
    func asNPSContent() -> NPSContent? {
        if case let .nps(content) = self {
            return content
        }
        return nil
    }

    /// Retrieves the locale code for the content.
    /// - Returns: A string representing the locale code of the content.
    func experienceLocale() -> String {
        switch self {
        case .flow(let content):
            return content.localeCode
        case .survey(let content):
            return content.localeCode
        case .nps(let content):
            return content.localeCode
        }
    }

    /// Retrieves the theme Id for the content.
    /// - Returns: An integer representing the base theme Id of the content.
    func experienceThemeId() -> Int {
        switch self {
        case .flow(let content):
            return content.baseThemeId
        case .survey(let content):
            return content.baseThemeId
        case .nps:
            return 0
        }
    }

    /// Retrieves the content associated with the current enum case.
    /// - Returns: The associated content (either FlowContent or SurveyContent).
    func content() -> Any {
        switch self {
        case .flow(let content):
            return content
        case .survey(let content):
            return content
        case .nps(let content):
            return content
        }
    }
}
