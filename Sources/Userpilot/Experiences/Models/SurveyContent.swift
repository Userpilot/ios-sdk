//
//  SurveyContent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 19/01/2025.
//

import Foundation

internal struct SurveyContentData: Decodable {
    let surveyContent: SurveyContent

    private enum CodingKeys: String, CodingKey {
        case surveyContent = "surveys"
    }
}

internal struct SurveyContent: Decodable {
    let id: Int
    let token: String
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
        case token
        case type
        case modules
        case metadata
        case surveyTheme = "theme_data"
        case screens
        case screenType = "screen_type"
        case localeCode = "locale_code"
        case timeDelay = "time_delay"
    }

    var baseThemeID: Int {
        return surveyTheme.id
    }

    var isForAllScreens: Bool {
        return screenType == .all
    }

}

internal struct SurveyMobileTheme: Decodable {
    let id: Int
    let themeData: SurveyTheme?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

internal struct SurveyContentMetaData: Decodable {
    let buttonLabel: String?

    private enum CodingKeys: String, CodingKey {
        case buttonLabel = "cta_label"
    }
}

internal struct SurveyStep: Decodable {
    let id: Int
    let isRequired: Bool?
    let logic: [SurveyLogic]?
    let metadata: Metadata?
    let question: String?
    let subheader: String?
    let type: SurveyViewType
    let buttonLabel: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case isRequired = "is_required"
        case buttonLabel = "button_label"
        case logic
        case metadata
        case question
        case subheader
        case type
    }
}

internal struct Metadata: Decodable {
    let highScore: String?
    let lowScore: String?
    let range: Int?
    let type: LikertViewType?
    let placeholder: String?
    let choices: [Choice]?
    let isMultiSelect: Bool?
    let otherChoice: OtherChoice?
    let enablePropertyCreation: Bool?
    let inputType: SingleTextType?
    let maxLength: Int?
    let propertyName: String?
    let buttonAction: String?
    let iosDeepLink: String?
    let androidDeepLink: String?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case highScore = "high_score"
        case lowScore = "low_score"
        case range
        case type
        case placeholder
        case choices
        case isMultiSelect = "is_multi_select"
        case otherChoice = "other_choice"
        case enablePropertyCreation = "enable_property_creation"
        case inputType = "input_type"
        case maxLength = "max_length"
        case propertyName = "property_name"
        case buttonAction = "button_action"
        case iosDeepLink = "ios_deep_link"
        case androidDeepLink = "android_deep_link"
        case enabled
    }
}

internal struct Choice: Decodable {
    let id: String?
    let value: String?
    var isSelected: Bool? = false
    var otherOptionText: String?
}

internal struct OtherChoice: Decodable {
    let enabled: Bool?
    let placeholder: String?
}

internal enum SurveyType: String, Decodable {
    case list
    case step
}

internal enum SurveyViewType: String, Decodable {
    case likert = "likert_scale"
    case openText = "open_text"
    case multipleChoice = "multiple_choice"
    case singleInput = "single_input"
    case completed = "completed"
}

internal enum LikertViewType: String, Decodable {
    case stars
    case hearts
    case emojis
    case numbers
}

internal enum SingleTextType: String, Decodable {
    case phone = "phone_number"
    case number = "number"
    case date = "date"
    case email = "email"
    case text = "text"
    case general = "general"
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `CarouselData` object using `JSONDecoder`.
    func toSurveyContent() -> SurveyContentData? {
        if let surveyContent: SurveyContentData = self.toObject() {
            return surveyContent
        } else {
            return nil
        }
    }
}
