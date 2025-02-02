//
//  UPExperienceView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A protocol that defines the requirements for an experience view in the Userpilot SDK.
//

internal protocol UPExperienceView: AnyObject {

    /// Validates whether the current input in the experience view is valid.
    /// - Returns: A `Bool` indicating whether the input meets the required validation criteria.
    func isValidAnswer() -> Bool

    /// Retrieves the user's input or answer from the experience view.
    /// - Returns: A `Payload` representing the user's answer.
    ///   `Payload` is defined as `[String: Any]?`.
    func getAnswerPayload() -> Payload

    /// Retrieves the user's input or answer from the experience view.
    /// - Returns: A `Payload` representing the user's answer.
    ///   `Payload` is defined as `[String: Any]?`.
    func getAnswer() -> Any?
}
