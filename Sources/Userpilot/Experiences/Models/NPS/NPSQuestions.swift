//
//  NPSQuestions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines NPS questions, follow-up answers and completion content.
//

import Foundation
import UIKit

// MARK: - NPSStep
internal struct NPSStep: Codable {
    let survey: Survey
    let followUp: FollowUp
    let completed: Completed

    private enum CodingKeys: String, CodingKey {
        case survey, completed
        case followUp = "follow_up"
    }
}

// MARK: - Survey
internal struct Survey: Codable {
    let question: String?
    let key: String?
    let lowScore: String?
    let highScore: String?
    let askMeLater: String?

    private enum CodingKeys: String, CodingKey {
        case question, key
        case lowScore = "low_score"
        case highScore = "high_score"
        case askMeLater = "ask_me_later"
    }
}

// MARK: - FollowUp
internal struct FollowUp: Codable {
    let type: NPSStepType
    let updateScore: String?
    let submit: String?
    let placeholder: String?
    let close: String?
    let all: FollowUpQuestion?
    let detractors: FollowUpQuestion?
    let passives: FollowUpQuestion?
    let promoters: FollowUpQuestion?

    private enum CodingKeys: String, CodingKey {
        case type, submit, placeholder, close, all, detractors, passives, promoters
        case updateScore = "update_score"
    }
}

// MARK: - FollowUpQuestion
internal struct FollowUpQuestion: Codable {
    let question: String?
    let key: String?
}

// MARK: - Completed
internal struct Completed: Codable {
    let all: CompletedData?
    let detractors: CompletedData?
    let passives: CompletedData?
    let promoters: CompletedData?
    let type: NPSStepType
}

// MARK: - CompletedData
internal struct CompletedData: Codable {
    let header: String?
    let subheader: String?
    let button: ButtonData
}

// MARK: - ButtonData
internal struct ButtonData: Codable {
    let buttonText: String?
    let close: String?
    let enabled: Bool
    let iosDeepLink: String?
    let buttonAction: ButtonActionType?

    enum CodingKeys: String, CodingKey {
        case buttonAction = "button_action"
        case buttonText = "button_text"
        case close, enabled
        case iosDeepLink = "deep_link_ios"
    }
}

// MARK: - Enums
internal enum NPSStepType: String, Codable {
    case universal
    case scoreBased = "score_based"
}
