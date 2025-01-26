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
        // If the survey step is not required, the answer is automatically valid.
        // Otherwise, checks if there is any selected rating item.
        return surveyStep?.isRequired != true || ratingItems.contains(where: { $0.isSelected })
    }

    // MARK: - Get Answer

    /// Retrieves the selected answer from the Likert scale and formats it as a Payload.
    /// - Returns: A dictionary containing the survey step ID, type, and the selected index value.
    func getAnswer() -> Payload {
        // Return an empty dictionary if no survey step is available
        guard let surveyStep = surveyStep else { return [:] }

        // Find the index of the last selected rating item (or -1 if none is selected)
        let selectedIndex = ratingItems.lastIndex(where: { $0.isSelected }) ?? -1

        // Return the answer as a dictionary with relevant data
        return [
            "id": surveyStep.id,
            "type": surveyStep.type,
            "value": selectedIndex
        ]
    }
}
