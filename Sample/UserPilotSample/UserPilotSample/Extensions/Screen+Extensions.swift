//
//  Screen+Extensions.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 01/09/2024.
//

import Foundation
import UIKit

public struct Screen {
    /// Retrieves the device bounds.
    public static var bounds: CGRect {
        return UIScreen.main.bounds
    }

    /// Retrieves the device width.
    public static var width: CGFloat {
        return bounds.width
    }

    /// Retrieves the device height.
    public static var height: CGFloat {
        return bounds.height
    }

    /// Retrieves the device scale.
    public static var scale: CGFloat {
        return UIScreen.main.scale
    }
}
