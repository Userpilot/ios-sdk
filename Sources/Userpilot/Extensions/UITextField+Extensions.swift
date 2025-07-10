//
//  UITextField+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 220/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `UITextField+Extension` contains extensions with helper methods for the `UITextField` class.
//

import Foundation
import UIKit
import ObjectiveC

internal extension UITextField {

    /// Adds padding to the start and end of the text field.
    /// - Parameters:
    ///   - start: The padding size (in points) to be added to the start (left side in LTR layouts).
    ///   - end: The padding size (in points) to be added to the end (right side in LTR layouts).
    func setPadding(
        start: CGFloat,
        end: CGFloat
    ) {
        let paddingViewStart = UIView(frame: CGRect(x: 0, y: 0, width: start, height: self.frame.height))
        let paddingViewEnd = UIView(frame: CGRect(x: 0, y: 0, width: end, height: self.frame.height))

        self.leftView = paddingViewStart
        self.leftViewMode = .always

        self.rightView = paddingViewEnd
        self.rightViewMode = .always
    }

    /// Validates the text field's input based on its keyboard type.
    /// - Returns: A `Bool` indicating whether the input is valid.
    ///
    /// Validation rules:
    /// - `.emailAddress`: Validates that the text is a valid email address.
    /// - `.phonePad`: Validates that the text is a valid phone number.
    /// - `.numberPad`, `.decimalPad`: Validates that the text contains numeric input.
    /// - Default: Validates that the text is not empty.
    func isValidAnswer() -> Bool {
        switch self.keyboardType {
        case .emailAddress:
            return self.text?.isValidEmail() ?? false
        case .phonePad:
            return self.text?.isEmpty == false && (self.text?.count ?? 0) > 3
        case .numberPad, .decimalPad:
            return self.text?.isNumeric() ?? false
        default:
            return self.text?.isNotEmpty ?? false
        }
    }

    /// Sets the placeholder text and its color.
    /// - Parameters:
    ///   - text: The placeholder text.
    ///   - color: The color of the placeholder text.
    func setPlaceholder(
        text: String,
        color: UIColor
    ) {
        self.attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key.foregroundColor: color]
        )
    }

    /// This method allows you to programmatically set the cursor position within a UITextField.
    func setCaretPosition(to position: Int) {
        let position = self.position(from: self.beginningOfDocument, offset: position)
        self.selectedTextRange = self.textRange(from: position!, to: position!)
    }

    /// Disable auto correct and suggestions
    func disableAutoCorrect() {
        self.autocorrectionType = .no
        self.spellCheckingType = .no
        self.smartQuotesType = .no
        self.smartDashesType = .no
        self.smartInsertDeleteType = .no
        self.autocapitalizationType = .none
    }

}

extension UITextView {

    /// Disable auto correct and suggestions
    func disableAutoCorrect() {
        self.autocorrectionType = .no
        self.spellCheckingType = .no
        self.smartQuotesType = .no
        self.smartDashesType = .no
        self.smartInsertDeleteType = .no
        self.autocapitalizationType = .none
    }
}

private var customTagKey: UInt8 = 0
internal extension UITextField {
    var customTag: String? {
        get {
            return objc_getAssociatedObject(self, &customTagKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &customTagKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
