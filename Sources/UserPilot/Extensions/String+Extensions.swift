//
//  String+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 27/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `String+Data` contains extensions with helper methods for the `String` class.
//  These extensions provide additional functionality for checking if strings and optional strings are not empty.
//

import Foundation
import UIKit

extension Optional where Wrapped == String {

    var isNotEmpty: Bool {
        return !(self?.isEmpty ?? true)
    }

}

extension String {

    var isNotEmpty: Bool {
        return !isEmpty
    }

}
