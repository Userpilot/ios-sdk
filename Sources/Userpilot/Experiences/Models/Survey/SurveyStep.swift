//
//  SurveyStep.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines survey steps, choices and input configuration.
//

import Foundation

internal struct SurveyStep: Codable {
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

internal struct Metadata: Codable {
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
    let buttonAction: ButtonActionType?
    let iosDeepLink: String?
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
        case enabled
    }
}

internal struct Choice: Codable {
    /// Missing IDs do not prevent display; only identified choices enter the answer payload.
    let id: String?
    let value: String?
    var isSelected: Bool? = false
    var otherOptionText: String?
}

internal struct OtherChoice: Codable {
    let enabled: Bool?
    let placeholder: String?
}

internal enum SurveyType: String, Codable {
    case list
    case step
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
    case text = "text"
    case general = "general"
}
