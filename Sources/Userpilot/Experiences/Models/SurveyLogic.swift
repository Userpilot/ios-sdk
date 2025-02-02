//
//  LogicContent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import Foundation

/// SurveyLogic contains survey step view logic for a question
struct SurveyLogic: Decodable {
    let action: SurveyLogicActionType?
    let metadata: LogicMetadata?
    let moduleId: Int?
    let operand: SurveyLogicOperandType?

    enum CodingKeys: String, CodingKey {
        case action
        case metadata
        case moduleId = "module_id"
        case operand
    }
}

struct LogicMetadata: Decodable {
    let value: ValueType?

    // Custom decoding logic for the `value` key
    enum ValueType: Decodable {
        case string(String)
        case array([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let arrayValue = try? container.decode([String].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value type")
            }
        }
    }
}

enum SurveyLogicActionType: String, Decodable {
    case goToModule = "go_to_module"
    case goToNextModule = "go_to_next_module"
    case endSurvey = "end_survey"
}

enum SurveyLogicOperandType: String, Decodable {
    case notKnown = "not_known"
    case known = "known"
    case contains = "contains"
    case notContains = "not_contains"
    case equals = "equals"
    case notEquals = "not_equals"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case all = "all"
    case any = "any"
}
