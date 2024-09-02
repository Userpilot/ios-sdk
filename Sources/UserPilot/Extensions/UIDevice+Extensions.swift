//
//  UIDevice+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// UIDevice+Data contains extensions helper methods
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
