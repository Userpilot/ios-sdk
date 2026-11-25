//
//  SurveyLogic.swift
//  Userpilot SDK
//
//  Created by Userpilot on 30/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Defines survey branching rules, conditions and target steps received from the backend.
//

import Foundation

/// SurveyLogic contains survey step view logic for a question
struct SurveyLogic: Codable {
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

struct LogicMetadata: Codable {
    let value: ValueType?

    // Custom decoding logic for the `value` key
    enum ValueType: Codable {
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

        /// Preserve the authored string-or-array shape instead of encoding enum case names.
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .array(let values):
                try container.encode(values)
            }
        }
    }
}

enum SurveyLogicActionType: String, Codable {
    case goToModule = "go_to_module"
    case goToNextModule = "go_to_next_module"
    case endSurvey = "end_survey"
}

enum SurveyLogicOperandType: String, Codable {
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
