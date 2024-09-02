//
//  File.swift
//  
//
//  Created by Motasem Hamed on 20/08/2024.
//

import Foundation
import UIKit

public extension UIWindow {
    /// Determines if this `UIWindow` is an internal Appcues SDK window.
    ///
    /// Implementations of `AppcuesElementTargeting` may need this value to reliably exclude any Appcues content windows
    /// that are overlaid on top of the application, when capturing screen layout information.
    var isAppcuesWindow: Bool {
        if #available(iOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
}
