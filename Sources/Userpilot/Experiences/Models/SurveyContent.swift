//
//  SurveyContent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 19/01/2025.
//

import Foundation

internal struct SurveyContentData: Codable {
    var surveyContent: SurveyContent

    private enum CodingKeys: String, CodingKey {
        case surveyContent = "surveys"
    }
}

internal struct SurveyContent: Codable {
    var id: Int
    var token: String
    var type: SurveyType
    var modules: [SurveyStep]
    var metadata: SurveyContentMetaData?
    var surveyTheme: SurveyMobileTheme
    var screens: [String]
    var screenType: ScreenType
    var localeCode: String

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
    }

    var baseThemeID: Int {
        return surveyTheme.id
    }

    var isForAllScreens: Bool {
        return screenType == .all
    }

}

internal struct SurveyMobileTheme: Codable {
    var id: Int
    var themeData: SurveyTheme?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

internal struct SurveyContentMetaData: Codable {
    var buttonLabel: String?

    private enum CodingKeys: String, CodingKey {
        case buttonLabel = "cta_label"
    }
}

internal struct SurveyStep: Codable {
    var id: Int
    var isRequired: Bool?
    var logic: [Logic]?
    var metadata: Metadata?
    var question: String?
    var subheader: String?
    var type: SurveyViewType
    var buttonLabel: String?

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

internal struct Logic: Codable {
    var action: String?
    var metadata: LogicMetadata?
    var moduleId: Int?
    var operand: String?

    private enum CodingKeys: String, CodingKey {
        case action
        case metadata
        case moduleId = "module_id"
        case operand
    }
}

internal struct LogicMetadata: Codable {
    var value: String?
}

internal struct Metadata: Codable {
    var highScore: String?
    var lowScore: String?
    var range: Int?
    var type: LikertViewType?
    var placeholder: String?
    var choices: [Choice]?
    var isMultiSelect: Bool?
    var otherChoice: OtherChoice?
    var enablePropertyCreation: Bool?
    var inputType: SingleTextType?
    var maxLength: Int?
    var propertyName: String?
    var buttonAction: String?
    var iosDeepLink: String?
    var androidDeepLink: String?
    var enabled: Bool?

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

internal struct Choice: Codable {
    var id: String?
    var value: String?
    var isSelected: Bool? = false
    var otherOptionText: String?
}

internal struct OtherChoice: Codable {
    var enabled: Bool?
    var placeholder: String?
}

internal enum SurveyType: String, Codable {
    case list = "list"
    case stepView = "step_view"
}

internal enum SurveyViewType: String, Codable {
    case likert = "likert_scale"
    case openText = "open_text"
    case multipleChoice = "multiple_choice"
    case singleInput = "single_input"
    case completed = "completed"
}

internal enum LikertViewType: String, Codable {
    case stars
    case hearts
    case emojis
    case numbers
}

internal enum SingleTextType: String, Codable {
    case phone = "phone_number"
    case number = "number"
    case date = "date"
    case email = "email"
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
