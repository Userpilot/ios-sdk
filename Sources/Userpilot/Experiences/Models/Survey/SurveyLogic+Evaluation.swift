//
//  SurveyLogic+Evaluation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pure evaluation of one survey rule; renderer and publisher state stay with their owners.
//

import Foundation

internal extension SurveyLogic {
    /// Preserves existing known/unknown handling and native answer coercion before evaluating metadata.
    func matches(answer: Any?, normalizedAnswer: String) -> Bool {
        if (answer == nil && operand == .notKnown) || operand == .known { return true }
        guard let metadata, let logicValue = extractLogicValue(from: metadata) else { return false }
        return matchesValue(
            answer: answer, normalizedAnswer: normalizedAnswer, metadata: metadata, logicValue: logicValue
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func matchesValue(
        answer: Any?, normalizedAnswer: String, metadata: LogicMetadata, logicValue: String
    ) -> Bool {
        switch operand {
        case .equals: return normalizedAnswer == logicValue
        case .notEquals: return normalizedAnswer != logicValue
        case .contains: return normalizedAnswer.contains(logicValue)
        case .notContains: return !normalizedAnswer.contains(logicValue)
        case .greaterThan: return (answer as? Int ?? Int.min) > (Int(logicValue) ?? Int.max)
        case .lessThan: return (answer as? Int ?? Int.max) < (Int(logicValue) ?? Int.min)
        case .all:
            guard let answerList = answer as? [String], let logicValues = extractLogicValues(from: metadata) else {
                return false
            }
            return Set(answerList).isSuperset(of: Set(logicValues))
        case .any:
            guard let answerList = answer as? [String], let logicValues = extractLogicValues(from: metadata) else {
                return false
            }
            return answerList.contains { logicValues.contains($0) }
        default: return false
        }
    }

    /// Process the action when the logic operand/condition is met
    func resolveAction(
        currentStep: Int,
        surveySteps: [SurveyStep]
    ) -> (Int, Bool) {
        switch action {
        case .endSurvey:
            return (surveySteps.count - 1, true)
        case .goToNextModule:
            return (currentStep + 1, false)
        case .goToModule:
            let index = moduleId.flatMap { moduleId in
                surveySteps.firstIndex { $0.id == moduleId } } ?? (currentStep + 1)
            return (index, false)
        default:
            return (currentStep + 1, false)
        }
    }

    /// Export the logic metadata value as string
    private func extractLogicValue(from metadata: LogicMetadata) -> String? {
        switch metadata.value {
        case .string(let value):
            return value
        case .array(let values):
            return values.first
        case .none:
            return nil
        }
    }

    /// Export the logic metadata value as array of string
    private func extractLogicValues(from metadata: LogicMetadata) -> [String]? {
        switch metadata.value {
        case .string(let value):
            return [value]
        case .array(let values):
            return values
        case .none:
            return nil
        }
    }
}
