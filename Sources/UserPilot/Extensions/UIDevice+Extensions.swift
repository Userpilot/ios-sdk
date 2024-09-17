//
//  UIDevice+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This file contains an extension for the `UIDevice` class, providing helper methods
//  to retrieve device-specific information such as a formatted identifier and device type.
//
//  Extensions include:
//  - `identifier`: Provides a formatted unique identifier for the device.
//  - `deviceType`: Provides the device name as the device type.
//

import Foundation
import UIKit

extension UIDevice {

    static var identifier: String {
        (current.identifierForVendor ?? UUID()).userpilotFormatted
    }

    static var deviceType: String {
        return UIDevice.current.name
    }

}
