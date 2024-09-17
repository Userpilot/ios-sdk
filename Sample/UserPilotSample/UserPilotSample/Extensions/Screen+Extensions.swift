//
//  Screen+Extensions.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 01/09/2024.
//
//  The `Screen` struct includes:
//  - `bounds`: The device's screen bounds.
//  - `width`: The device's screen width.
//  - `height`: The device's screen height.
//  - `scale`: The scale factor of the device's screen.
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
