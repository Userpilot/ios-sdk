//
//  SurveyContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Decodes survey content, question steps and presentation settings received from the backend.
//

import Foundation

internal struct SurveyContentData: Codable {
    // A response can contain another content type; absence is not a decoding failure.
    let surveyContent: SurveyContent?

    private enum CodingKeys: String, CodingKey {
        case surveyContent = "surveys"
    }
}

internal struct SurveyContent: Codable {
    let id: Int
    let type: SurveyType
    var modules: [SurveyStep]
    let metadata: SurveyContentMetaData?
    let surveyTheme: SurveyMobileTheme
    let screens: [String]
    let screenType: ScreenType
    let localeCode: String
    let timeDelay: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case modules
        case metadata
        case surveyTheme = "theme_data"
        case screens
        case screenType = "screen_type"
        case localeCode = "locale_code"
        case timeDelay = "time_delay"
    }

    var baseThemeId: Int {
        return surveyTheme.id
    }

    var isForAllScreens: Bool {
        return screenType == .all
    }

    var delayDuration: TimeInterval {
        return TimeInterval(timeDelay)
    }

}

internal extension SurveyContent {
    /// A resolved app theme decides first; then the embedded position, then the cached theme's dialog flag.
    func isBottomSheet(using themes: ThemeHandling) -> Bool {
        if let appTheme = themes.appTheme {
            return !appTheme.isDialogSurvey
        }
        if let position = surveyTheme.themeData?.general?.position {
            return position == .bottom
        }
        return themes.getThemeById(surveyTheme.id)?.isDialogSurvey == false
    }
}

internal struct SurveyMobileTheme: Codable {
    let id: Int
    let themeData: SurveyTheme?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

internal struct SurveyContentMetaData: Codable {
    let buttonLabel: String?

    private enum CodingKeys: String, CodingKey {
        case buttonLabel = "cta_label"
    }
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `SurveyContentData`; a failure is logged through `logger` and returns `nil`.
    func toSurveyContent(logger: Logging? = nil) -> SurveyContentData? {
        let data: SurveyContentData? = toObject(logger: logger)
        return data?.surveyContent == nil ? nil : data
    }
}

internal extension SurveyContent {
    /// Returns the final thank-you action's link; URL validation stays with the navigation caller.
    var thankYouDeepLink: String? {
        guard let module = modules.last,
              module.type == .completed,
              module.metadata?.buttonAction == .deepLink else { return nil }
        return module.metadata?.iosDeepLink
    }
}
