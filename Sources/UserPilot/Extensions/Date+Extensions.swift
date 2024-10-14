//
//  Date+Extension.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Date+Extension` contains extensions with helper methods for the `Date` class.
//  It provides additional functionality to format dates and calculate time intervals.
//

import Foundation
import UIKit

internal extension Date {

    var fullDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: self)
    }

    var millisecondsSince1970: Double {
        return (self.timeIntervalSince1970 * 1_000.0).rounded()
    }

}
