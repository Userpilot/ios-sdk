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

    /// Validates whether the answer is valid based on the survey step requirements.
    ///
    /// This method checks whether the survey step is required and if any choice is selected.
    /// If the step is not required or at least one choice is selected, it returns `true`.
    /// Otherwise, it returns `false`.
    ///
    /// - Returns: A boolean indicating whether the answer is valid.
    func isValidAnswer() -> Bool {
        // Return true if the survey step is not required or any option is selected
        return surveyStep?.isRequired != true || choices.contains(where: { $0.isSelected == true })
    }

    /// Retrieves the answer for the current survey step as a dictionary payload.
    ///
    /// This method returns a dictionary containing the survey step's `id`, `type`,
    /// and the selected choices' `id`s as the value.
    ///
    /// - Returns: A dictionary representing the answer, with survey step details and selected options.
    func getAnswer() -> Payload {
        guard let surveyStep = surveyStep else {
            return [:] // return an empty dictionary if surveyStep is nil
        }

        // Filter selected options and map their IDs
        let selectedOptions = choices.filter { $0.isSelected == true }.map { $0.id }

        // Return the answer payload as a dictionary
        return [
            "id": surveyStep.id as Any,
            "type": surveyStep.type as Any,
            "value": selectedOptions
        ]
    }
}
