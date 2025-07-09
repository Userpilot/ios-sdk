//
//  UPSingleInputView+UITextFieldDelegate.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to handle UITextFieldDelegate.
//

import UIKit

// MARK: - UITextFieldDelegate Extension for UPSingleInputView

extension UPSingleInputView: UITextFieldDelegate {

    /// Determines whether the text in the `UITextField` should change. This method handles custom
    /// formatting and validation for input types like date and phone numbers.
    ///
    /// - Parameters:
    ///   - textField: The `UITextField` instance where the text change is occurring.
    ///   - range: The range of characters to be replaced.
    ///   - string: The replacement string.
    /// - Returns: A `Bool` value indicating whether the text should change.
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {

        var result = true
        // Check the input type and apply specific behavior
        if surveyStep?.metadata?.inputType == .date {
            // Format the input as a date in "dd/MM/yyyy"
            result = formatDate(string)
        } else if surveyStep?.metadata?.inputType == .phone {
            // Allow only numeric characters for phone input
            let allowedCharacters = CharacterSet.decimalDigits
            let isValidInput = string.rangeOfCharacter(from: allowedCharacters.inverted) == nil
            result = isValidInput && isStringLengthValid(range, string, surveyStep?.metadata?.maxLength ?? 100)
        } else if surveyStep?.metadata?.inputType == .text {
            // Allow only alphabetic characters for input
            let allowedCharacters = CharacterSet.letters
            let isValidInput = string.rangeOfCharacter(from: allowedCharacters.inverted) == nil
            result = isValidInput && isStringLengthValid(range, string, surveyStep?.metadata?.maxLength ?? 100)
        } else {
            // Default case: Enforce maximum length validation
            result = isStringLengthValid(range, string, surveyStep?.metadata?.maxLength ?? 100)
        }
        viewStateProtocol?.onViewStateChanged(isValid: isValidAnswer())
        return result
    }

    /// Notifies the `viewStateProtocol` when the text in the `UITextField` changes. This allows
    /// the protocol to track the validity of the input in real time.
    ///
    /// - Parameter textField: The `UITextField` instance whose text has changed.
    @objc func textDidChange(_ textField: UITextField) {
        if surveyStep?.metadata?.inputType == .email {
            if let email = textField.text, email.isValidEmail() {
                textField.layer.borderColor = UIColor.grayCA.cgColor
            } else {
                textField.layer.borderColor = UIColor.red.cgColor
            }
        }
        viewStateProtocol?.onViewStateChanged(isValid: isValidAnswer())
    }

    /// Handles the Return key tap by dismissing the keyboard.
    ///
    /// - Parameter textField: The `UITextField` instance where the Return key was tapped.
    /// - Returns: `true` to allow the default behavior of resigning the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }

    /// Validates pasted text to ensure it adheres to the input type constraints (e.g., numeric for phone input).
    ///
    /// - Parameters:
    ///   - textField: The `UITextField` instance receiving the pasted text.
    ///   - range: The range of characters being replaced.
    ///   - text: The replacement text being pasted.
    /// - Returns: A `Bool` value indicating whether the pasted text is valid.
    func textField(
        _ textField: UITextField,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if surveyStep?.metadata?.inputType == .phone {
            // Validate numeric input for phone numbers
            let allowedCharacters = CharacterSet.decimalDigits
            let isValidInput = text.rangeOfCharacter(from: allowedCharacters.inverted) == nil
            return isValidInput
        } else {
            return true
        }
    }

    // MARK: - Helper Methods

    /// Validates the length of the updated text after applying the specified change.
    ///
    /// - Parameters:
    ///   - range: The range of characters to be replaced.
    ///   - string: The replacement string.
    ///   - length: The maximum allowed length.
    /// - Returns: A `Bool` indicating whether the updated text length is within the limit.
    private func isStringLengthValid(
        _ range: NSRange,
        _ string: String,
        _ length: Int
    ) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= length
    }

    /// Formats the input string as a date in the "dd/MM/yyyy" format.
    ///
    /// - Parameter string: The replacement string.
    /// - Returns: `false` to prevent the default text change behavior, as the text is updated manually.
    private func formatDate(_ string: String) -> Bool {
        // Allow only numeric characters
        let allowedCharacters = CharacterSet.decimalDigits
        let isValidInput = string.rangeOfCharacter(from: allowedCharacters.inverted) == nil
        if !isValidInput {
            return false
        }

        // Clean and update the date string
        var cleanDate = (textField.text ?? "").replacingOccurrences(of: "[^\\d]", with: "", options: .regularExpression)

        // Handle backspace or append new character
        if string.isEmpty {
            cleanDate = String(cleanDate.dropLast())
        } else {
            cleanDate.append(string)
        }

        // Limit length to 8 digits
        cleanDate = String(cleanDate.prefix(8))

        // Apply "dd/MM/yyyy" formatting
        var formattedDate = ""
        for (index, char) in cleanDate.enumerated() {
            formattedDate.append(char)
            if index == 1 || index == 3 {
                formattedDate.append("/")
            }
        }

        // Update the text field and move the cursor
        textField.text = formattedDate
        if let textLength = textField.text?.count {
            textField.setCaretPosition(to: textLength)
        }

        return false
    }
}
