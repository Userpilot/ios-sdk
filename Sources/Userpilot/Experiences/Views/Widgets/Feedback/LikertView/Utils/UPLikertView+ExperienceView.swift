//
//  Untitled.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  This extension implements the UPExperienceView protocol for the UPLikertView class.
//  It includes methods for checking the validity of an answer and retrieving the selected answer
//  from the Likert scale, returning the data in a specific format.

extension UPLikertView: UPExperienceView {

    // MARK: - Answer Validation

    /// Checks if the current answer is valid.
    /// A valid answer is either when the survey step is not required or when at least one item is selected.
    /// - Returns: A boolean indicating if the answer is valid.
    func isValidAnswer() -> Bool {
        return surveyStep?.isRequired != true || ratingItems.contains(where: { $0.isSelected })
    }

    // MARK: - Get Answer

    /// Retrieves the selected answer from the Likert scale and formats it as a Payload.
    /// - Returns: A dictionary containing the survey step ID, type, and the selected index value.
    func getAnswerPayload() -> Payload {
        guard
            let surveyStep = surveyStep,
            let answer = getAnswer()
        else { return nil }

        // Return the answer as a dictionary with relevant data
        return [
            "id": surveyStep.id,
            "type": surveyStep.type,
            "value": answer
        ]
    }

    /// Retrieves the 1-based index of the last selected rating item.
    ///
    /// This method searches for the last selected item in the rating list and returns its position (1-based index).
    /// - If no items are selected, it returns `nil`.
    /// - Otherwise, it returns the last selected item's index +1 to make it 1-based.
    ///
    /// - Returns: An optional `Int` representing the 1-based index of the
    ///  last selected item, or `nil` if no selection exists.
    func getAnswer() -> Any? {
        guard let lastSelectedIndex = ratingItems.lastIndex(where: { $0.isSelected }) else {
            return nil
        }
        return lastSelectedIndex + 1
    }
}
