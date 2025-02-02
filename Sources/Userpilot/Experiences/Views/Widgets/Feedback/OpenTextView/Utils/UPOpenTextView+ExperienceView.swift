//
//  UPOpenTextView+ExperienceView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to confirm UPExperienceView
//

extension UPOpenTextView: UPExperienceView {

    /// Checks if the answer is valid based on the survey step's requirements.
    ///
    /// This method checks if the `surveyStep` is marked as required and whether the text
    ///  in the text view is empty or not.
    /// If the survey step is not required or the text view contains some text, it
    ///  returns `true`; otherwise, it returns `false`.
    ///
    /// - Returns: A boolean indicating whether the answer is valid.
    func isValidAnswer() -> Bool {
        return surveyStep?.isRequired != true || !(textView.text?.isEmpty ?? true)
    }

    /// Retrieves the answer from the text view as a payload dictionary.
    ///
    /// This method constructs a dictionary containing the `id`, `type`, and `value` of
    ///  the `surveyStep`,
    /// with the value being the current text in the text view. If the `surveyStep` is `nil`,
    ///  an empty dictionary is returned.
    ///
    /// - Returns: A dictionary (`Payload`) representing the answer with keys "id", "type", and "value".
    func getAnswerPayload() -> Payload {
        guard
            let surveyStep = surveyStep,
            let answer = getAnswer()
        else { return nil }

        return [
            "id": surveyStep.id as Any,
            "type": surveyStep.type as Any,
            "value": answer
        ]
    }

    /// Retrieves the answer from the `editText` field, if it contains text.
    ///
    /// This method checks if the `editText` field is not empty or `nil`. If it
    /// contains any text, it returns the text as a `String`.
    /// Otherwise, it returns `nil`.
    ///
    /// - Returns: A `String?` containing the text from the `editText` field, or `nil` if the text is empty or `nil`.
    func getAnswer() -> Any? {
        return textView.text?.isEmpty == false ? textView.text : nil
    }

}
