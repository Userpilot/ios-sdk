//
//  SurveyAnswerState.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns form values independently from SwiftUI view identity and serializes the existing answer contract.
//

import UIKit

/// A question's value survives layout, keyboard and SwiftUI body updates.
internal struct SurveyAnswerState {
    var text = ""
    var rating: Int?
    var selectedChoices: Set<Int> = []
    var otherText = ""
    var countryCode = "+1"

    /// Preserve the legacy optional-question policy; optional invalid input is still submittable.
    func isValid(for step: SurveyStep) -> Bool {
        guard step.isRequired == true else { return true }
        switch step.type {
        case .likert: return rating != nil
        case .multipleChoice: return !selectedChoices.isEmpty
        case .openText: return !text.isEmpty
        case .singleInput:
            if step.metadata?.inputType == .date { return text.count == 10 }
            return text.isValidAnswer(keyboardType: step.inputKeyboardType)
        case .completed: return true
        }
    }

    /// Branch rules consume IDs, while the submitted Other option includes its text.
    func answer(for step: SurveyStep) -> Any? {
        switch step.type {
        case .likert: return rating
        case .multipleChoice:
            let values = choiceIDs(for: step, includeOtherText: false)
            guard !values.isEmpty else { return nil }
            if step.metadata?.isMultiSelect == true { return values }
            return values.first ?? nil
        case .openText, .singleInput:
            // The native phone widget includes its country prefix even for an optional blank answer.
            if step.type == .singleInput, step.metadata?.inputType == .phone { return countryCode + text }
            return text.isEmpty ? nil : text
        case .completed: return nil
        }
    }

    func payload(for step: SurveyStep) -> Payload {
        guard let answer = answer(for: step) else { return nil }
        return [
            "id": step.id, "type": step.type.rawValue,
            "value": step.type == .multipleChoice ? choiceIDs(for: step, includeOtherText: true) : answer
        ]
    }

    mutating func toggleChoice(_ index: Int, for step: SurveyStep) {
        if step.metadata?.isMultiSelect == true {
            if selectedChoices.contains(index) { selectedChoices.remove(index) } else { selectedChoices.insert(index) }
        } else {
            selectedChoices = [index]
        }
    }

    /// Keep the established input limits and filtering outside the platform text controls.
    mutating func updateText(_ value: String, for step: SurveyStep) {
        let limit = max(0, (step.type == .openText ? 500 : step.metadata?.maxLength ?? 100))
        if step.metadata?.inputType == .phone, value.rangeOfCharacter(from: .decimalDigits.inverted) != nil { return }
        if step.metadata?.inputType == .text, value.rangeOfCharacter(from: .letters.inverted) != nil { return }
        if step.metadata?.inputType == .date {
            let digits = Array(value.filter(\.isNumber).prefix(8))
            text = digits.enumerated().map { index, digit in
                (index == 2 || index == 4 ? "/" : "") + String(digit)
            }.joined()
        } else {
            text = String(value.prefix(limit))
        }
    }

    private func choiceIDs(for step: SurveyStep, includeOtherText: Bool) -> [String?] {
        let choices = step.metadata?.choices ?? []
        return selectedChoices.sorted().compactMap { index -> String?? in
            if index == choices.count, step.metadata?.otherChoice?.enabled == true {
                return ThemeHandler.DefaultValues.surveyOtherChoice + (includeOtherText ? otherText : "")
            }
            guard choices.indices.contains(index) else { return nil }
            return .some(choices[index].id)
        }
    }
}

extension SurveyStep {
    var inputKeyboardType: UIKeyboardType {
        switch metadata?.inputType {
        case .phone: return .phonePad
        case .number, .date: return .numberPad
        case .email: return .emailAddress
        default: return .default
        }
    }
}

extension SurveyContent {
    /// A branching survey has no fixed remaining question count to display.
    var hasBranchingLogic: Bool {
        modules.contains { step in
            step.logic?.contains { $0.action == .goToModule || $0.action == .endSurvey } == true
        }
    }
}
