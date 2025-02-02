//
//  UPMultipleChoiceView+ExperienceView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Extension of `UPMultipleChoiceView` to conform to `UPExperienceView` protocol.
//  Provides methods to validate the answer and retrieve the answer payload.
//

extension UPMultipleChoiceView: UPExperienceView {

    // MARK: - UPExperienceView

    /// Validates whether the answer meets the survey step's requirements.
    ///
    /// This method checks if the survey step is required and whether at least one choice is selected.
    /// - If the step is not required, it returns `true`.
    /// - If the step is required, it returns `true` only if at least one choice is selected.
    /// - Otherwise, it returns `false`.
    ///
    /// - Returns: A boolean indicating whether the answer is valid.
    func isValidAnswer() -> Bool {
        return surveyStep?.isRequired != true || choices.contains(where: { $0.isSelected == true })
    }

    /// Retrieves the answer for the current survey step as a dictionary payload.
    ///
    /// This method constructs a dictionary containing:
    /// - The `id` and `type` of the survey step.
    /// - The selected choices' `id`s as the value.
    /// - If an "Other" choice is selected, it includes the user-provided text.
    ///
    /// If no choices are selected, the function returns `nil`.
    ///
    /// - Returns: A dictionary representing the answer, including survey step
    ///  details and selected options, or `nil` if no choices are selected.
    func getAnswerPayload() -> Payload {
        guard let surveyStep = surveyStep else {
            return nil // Return nil if `surveyStep` is nil
        }

        // Extract selected option IDs
        var selectedOptions = choices.filter { $0.isSelected == true }.map { $0.value }

        // Handle "Other" option logic
        if let lastChoice = choices.last,
           lastChoice.id == ThemeHandler.DefaultValues.surveyOtherChoice,
           lastChoice.isSelected == true {

            if let otherText = lastChoice.otherOptionText, !otherText.isEmpty {
                selectedOptions = selectedOptions.dropLast() +
                [ThemeHandler.DefaultValues.surveyOtherChoice + otherText]
            }
        }

        // Return nil if no options are selected
        guard !selectedOptions.isEmpty else { return nil }

        // Construct and return the answer payload
        return [
            "id": surveyStep.id as Any,
            "type": surveyStep.type as Any,
            "value": selectedOptions
        ]
    }

    /// Retrieves the selected answer(s) based on the survey step requirements.
    ///
    /// This method checks which choices have been selected and returns their IDs.
    /// - If no choices are selected, it returns `nil`.
    /// - If the survey step allows multiple selections, it returns an array of selected IDs.
    /// - Otherwise, it returns the first selected ID.
    ///
    /// - Returns: An optional value containing either an array of selected IDs or a single selected ID.
    func getAnswer() -> Any? {
        let selectedIds = choices.filter { $0.isSelected == true }.map { $0.id }
        if selectedIds.isEmpty {
            return nil
        }
        return surveyStep?.metadata?.isMultiSelect == true ? selectedIds : selectedIds.first
    }

}
