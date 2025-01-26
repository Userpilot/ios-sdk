//
//  UPSingleInputView+ExperienceView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to confirm UPExperienceView
//

import UIKit

// MARK: - UPExperienceView Protocol Implementation for UPSingleInputView

extension UPSingleInputView: UPExperienceView {

    // MARK: - Answer Validation

    /// Validates if the answer provided in the text field is valid.
    ///
    /// The answer is considered valid if:
    /// - The `surveyStep` is not marked as required, or
    /// - The text field contains a valid answer.
    ///
    /// - Returns: A boolean indicating whether the answer is valid.
    func isValidAnswer() -> Bool {
        return surveyStep?.isRequired != true || textField.isValidAnswer()
    }

    // MARK: - Get Answer

    /// Retrieves the answer provided by the user, formatted as a dictionary payload.
    ///
    /// The payload contains:
    /// - `"id"`: The ID of the survey step.
    /// - `"type"`: The type of the survey step.
    /// - `"value"`: The answer given by the user (formatted based on text field input).
    ///
    /// - Returns: A dictionary representing the answer in a key-value format.
    func getAnswer() -> Payload {
        guard let surveyStep = surveyStep else { return [:] }

        return [
            "id": surveyStep.id,
            "type": surveyStep.type,
            "value": answer()
        ]
    }

    // MARK: - Answer Formatting

    /// Formats the answer based on the text field input and keyboard type.
    private func answer() -> String {
        switch textField.keyboardType {
        case .phonePad:
            if let countryCode = countrySelectorButton.titleLabel?.text, let text = textField.text {
                return "\(countryCode)\(text)"
            }
            return ""
        default:
            return textField.text ?? ""
        }
    }
}
