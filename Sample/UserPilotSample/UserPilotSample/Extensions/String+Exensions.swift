//
//  String+Exensions.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

extension Optional where Wrapped == String {

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
