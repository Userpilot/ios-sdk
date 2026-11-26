//
//  UPMultipleChoiceView+ExperienceView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  Extension of `UPMultipleChoiceView` to conform to `UPExperienceViewDelegate` protocol.
//  Provides methods to validate the answer and retrieve the answer payload.
//

import Foundation

extension UPMultipleChoiceView: UPExperienceViewDelegate {

    // MARK: - UPExperienceViewDelegate

    /// Validates whether the answer meets the survey step's requirements.
    ///
    /// A required step needs a selected choice with an ID that can be submitted.
    func isValidAnswer() -> Bool {
        return surveyStep?.isRequired != true || choices.contains { $0.isSelected == true && $0.id != nil }
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
        var selectedOptions = choices.filter { $0.isSelected == true }.compactMap { $0.id }

        // Handle "Other" option logic
        if let lastChoice = choices.last,
           lastChoice.id == Constants.Theme.surveyOtherChoice,
           lastChoice.isSelected == true {

            if let otherChiceCell = tableView.cellForRow(
                at: IndexPath(row: choices.count - 1, section: 0)) as? ChoiceTableViewCell {
                selectedOptions = selectedOptions.dropLast() +
                [Constants.Theme.surveyOtherChoice + (otherChiceCell.getOtherOptionText() ?? "")]
            }
        }

        // Return nil if no options are selected
        guard !selectedOptions.isEmpty else { return nil }

        // Construct and return the answer payload
        return [
            "id": surveyStep.id,
            "type": surveyStep.type.rawValue,
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
        let selectedIds = choices.filter { $0.isSelected == true }.compactMap { $0.id }
        if selectedIds.isEmpty {
            return nil
        }
        if surveyStep?.metadata?.isMultiSelect == true {
            return selectedIds
        } else {
            return selectedIds.first ?? nil
        }
    }

}
