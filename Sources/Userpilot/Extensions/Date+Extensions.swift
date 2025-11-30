//
//  Date+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
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

    func isMoreThanOneSecond(from other: Date) -> Bool {
        return abs(self.timeIntervalSince(other)) > 1.0
    }

    func isLessThanTenSecond(from other: Date) -> Bool {
        return abs(self.timeIntervalSince(other)) < 10.0
    }

}
