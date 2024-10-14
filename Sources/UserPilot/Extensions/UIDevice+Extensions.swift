//
//  UIDevice+Extension.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  UIDevice+Extension file contains an extension for the `UIDevice` class, providing helper methods
//  to retrieve device-specific information such as a formatted identifier and device type.
//

import Foundation
import UIKit

internal extension UIDevice {

    static var identifier: String {
        (current.identifierForVendor ?? UUID()).userpilotFormatted
    }

    static var deviceType: String {
        return UIDevice.current.name
    }

}
