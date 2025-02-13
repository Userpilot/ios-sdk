//
//  SurveyLogicHandler.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/02/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
// Handles logic for determining the next question in a survey based on step logic and answers.
//

import Foundation

internal struct SurveyLogicHandler {

    // Determines the next question index based on the current step, logic rules, provided answer, and survey steps.
    // - Parameters:
    //   - currentStep: The index of the current question in the survey.
    //   - stepLogic: List of `SurveyLogic` defining the conditional logic for survey steps.
    //   - answer: The user's answer to the current question.
    //   - surveySteps: List of all survey steps.
    // - Returns: The index of the next step in the survey.
    // swiftlint:disable:next cyclomatic_complexity
    static func getNextQuestionIndex(
        currentStep: Int,
        stepLogic: [SurveyLogic],
        answer: Any?,
        surveySteps: [SurveyStep]
    ) -> (Int, Bool) {
        let normalizedAnswer = mapListAnswerToAnswer(answer)

        for logic in stepLogic {
            // Handle NOT_KNOWN and KNOWN cases
            if (answer == nil && logic.operand == .notKnown) || logic.operand == .known {
                return resolveAction(logic: logic, currentStep: currentStep, surveySteps: surveySteps)
            }

            guard let metadata = logic.metadata, let logicValue = extractLogicValue(from: metadata) else { continue }

            let conditionMet: Bool = {
                switch logic.operand {
                case .equals:
                    return normalizedAnswer == logicValue
                case .notEquals:
                    return normalizedAnswer != logicValue
                case .contains:
                    return normalizedAnswer.contains(logicValue)
                case .notContains:
                    return !normalizedAnswer.contains(logicValue)
                case .greaterThan:
                    return (answer as? Int ?? Int.min) > (Int(logicValue) ?? Int.max)
                case .lessThan:
                    return (answer as? Int ?? Int.max) < (Int(logicValue) ?? Int.min)
                case .all:
                    if let answerList = answer as? [String], let logicValues = extractLogicValues(from: metadata) {
                        return Set(answerList).isSuperset(of: Set(logicValues))
                    }
                    return false
                case .any:
                    if let answerList = answer as? [String], let logicValues = extractLogicValues(from: metadata) {
                        return answerList.contains { logicValues.contains($0) }
                    }
                    return false
                default:
                    return false
                }
            }()

            if conditionMet {
                return resolveAction(logic: logic, currentStep: currentStep, surveySteps: surveySteps)
            }
        }

        return (currentStep + 1, false)
    }

    /// Process the action when the logic operand/condition is met
    private static func resolveAction(logic: SurveyLogic, currentStep: Int, surveySteps: [SurveyStep]) -> (Int, Bool) {
        switch logic.action {
        case .endSurvey:
            return (surveySteps.count - 1, true)
        case .goToNextModule:
            return (currentStep + 1, false)
        case .goToModule:
            let index = logic.moduleId.flatMap { moduleId in
                surveySteps.firstIndex { $0.id == moduleId } } ?? (currentStep + 1)
            return (index, false)
        default:
            return (currentStep + 1, false)
        }
    }

    /// Extract the answer from the list when its list from one value
    private static func mapListAnswerToAnswer(_ answer: Any?) -> String {
        if let answerList = answer as? [String], answerList.count == 1 {
            return answerList.first ?? ""
        }
        return String(describing: answer ?? "")
    }

    /// Export the logic metadata value as string
    private static func extractLogicValue(from metadata: LogicMetadata) -> String? {
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
    private static func extractLogicValues(from metadata: LogicMetadata) -> [String]? {
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
