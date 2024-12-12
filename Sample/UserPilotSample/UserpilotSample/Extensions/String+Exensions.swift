//
//  String+Exensions.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//
//  Extensions include:
//  - `isNilOrEmpty`: Checks if the string is nil or empty.
//  - `isValidInput`: Checks if the string has a minimum length of 6 characters, indicating valid input.
//  - `isValidPassword`: Checks if the string has a minimum length of 4 characters, indicating a valid password.
//

import Foundation
import UIKit

internal extension Optional where Wrapped == String {

    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }

    var isValidInput: Bool {
        return self?.count ?? 0 >= 6
    }

    var isValidPassword: Bool {
        return self?.count ?? 0 >= 4
    }

}

internal extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
