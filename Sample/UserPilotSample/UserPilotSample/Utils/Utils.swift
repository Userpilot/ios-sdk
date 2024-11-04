//
//  Utils.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

func delay(_ delay: Double, closure: @escaping () -> Void) {

    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)

}

// Function to read from the plist
func readConfigValue(forKey key: String) -> Any? {
    return Bundle.main.infoDictionary?[key]
}
