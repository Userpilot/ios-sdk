//
//  Date+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Date+Data` contains extensions with helper methods for the `Date` class.
//  It provides additional functionality to format dates and calculate time intervals.
//
//  Extensions include:
//  - `fullDateString`: Returns the date in a full date and time format.
//  - `millisecondsSince1970`: Returns the time interval since January 1, 1970, in milliseconds.
//

import Foundation
import UIKit

extension Date {

    var fullDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full // This gives a full date format (e.g., "Monday, August 19, 2024")
        dateFormatter.timeStyle = .medium // Medium time format (e.g., "3:30:32 PM")
        return dateFormatter.string(from: self)
    }

    var millisecondsSince1970: Double {
        return (self.timeIntervalSince1970 * 1_000.0).rounded()
    }

}
