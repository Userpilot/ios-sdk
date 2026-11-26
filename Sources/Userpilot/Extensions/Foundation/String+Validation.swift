//
//  String+Validation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Validates survey answer strings using the existing native keyboard and regex rules.
//

import Foundation
import UIKit

internal extension String {
    // Function to return valid email address
    func isValidEmail() -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: self.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }

    // Function to return valid phone number
    func isValidPhone() -> Bool {
        // Example phone validation (simple version)
        let phoneRegex = "^[0-9]{10}$"
        let regex = try? NSRegularExpression(pattern: phoneRegex, options: [])
        let range = NSRange(location: 0, length: self.count)
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }

    // Function to check if the string is numaric
    func isNumeric() -> Bool {
        return Double(self) != nil
    }

    /// Keeps the existing keyboard-specific answer rules; phone answers only require four characters.
    func isValidAnswer(keyboardType: UIKeyboardType) -> Bool {
        switch keyboardType {
        case .emailAddress:
            return isValidEmail()
        case .phonePad:
            return !isEmpty && count > 3
        case .numberPad, .decimalPad:
            return isNumeric()
        default:
            return !isEmpty
        }
    }
}
