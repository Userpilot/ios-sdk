//
//  SurveyLogicHandler.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/02/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Handles logic for determining the next question in a survey based on step logic and answers.
//

import Foundation

/// Stateless survey branching contract; callers can select an evaluator without owning mutable state.
internal protocol SurveyLogicHandling {
    static func getNextQuestionIndex(
        currentStep: Int, stepLogic: [SurveyLogic], answer: Any?, surveySteps: [SurveyStep]
    ) -> (Int, Bool)
}

internal struct SurveyLogicHandler: SurveyLogicHandling {
    /// Applies the first matching rule, preserving backend rule order and the existing next-step fallback.
    static func getNextQuestionIndex(
        currentStep: Int, stepLogic: [SurveyLogic], answer: Any?, surveySteps: [SurveyStep]
    ) -> (Int, Bool) {
        let normalizedAnswer = mapListAnswerToAnswer(answer)
        guard let logic = stepLogic.first(where: {
            $0.matches(answer: answer, normalizedAnswer: normalizedAnswer)
        }) else {
            return (currentStep + 1, false)
        }
        return logic.resolveAction(currentStep: currentStep, surveySteps: surveySteps)
    }

    /// Extract the answer from the list when its list from one value
    private static func mapListAnswerToAnswer(_ answer: Any?) -> String {
        if let answerList = answer as? [String], answerList.count == 1 {
            return answerList.first ?? ""
        }
        if let stringAnswer = answer as? String {
            return stringAnswer
        }
        if let intAnswer = answer as? Int {
            return String(intAnswer)
        }
        return ""
    }

}
