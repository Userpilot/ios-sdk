//
//  UIColor+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 01/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `Bundle+Data` contains extensions with helper methods for the `Bundle` class.
//  These methods provide convenient access to various pieces of information from the app's bundle,
//  including identifiers, names, versions, and build numbers.
//

import Foundation
import UIKit

internal extension UIColor {
    // static let gray = UIColor(hexString: "#656567")
    static let lightGray = UIColor(hex: "#EBEBEB")
    static let grayCA = UIColor(hex: "#CACACE")
    static let gray43 = UIColor(hex: "#434345")
    static let grayA8 = UIColor(hex: "#A8A8AC")
}

 extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
 }

internal extension UIColor {

    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 || hex.count == 8 else { return nil }

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alphaValue, redValue, greenValue, blueValue: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (alphaValue, redValue, greenValue, blueValue) = (255, (int >> 16) &
                                                             0xFF, (int >> 8) &
                                                             0xFF, int &
                                                             0xFF)
        case 8: // ARGB (32-bit)
            (alphaValue, redValue, greenValue, blueValue) = ((int >> 24) &
                                                             0xFF, (int >> 16) &
                                                             0xFF, (int >> 8) &
                                                             0xFF, int &
                                                             0xFF)
        default:
            return nil
        }

        self.init(red: CGFloat(redValue) / 255,
                  green: CGFloat(greenValue) / 255,
                  blue: CGFloat(blueValue) / 255,
                  alpha: CGFloat(alphaValue) / 255)
    }

}

internal extension UIColor {
    // Function to generate a random color
    static func random() -> UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    func isLightColor() -> Bool {
        // Get the red, green, blue, and alpha components of the color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate luminance using the same formula
        let luminance = (0.299 * red + 0.587 * green + 0.114 * blue)

        // Return true if the color is dark, false otherwise
        return luminance > 0.5
    }

    func withOpacity(_ opacity: CGFloat) -> UIColor {
        return self.withAlphaComponent(opacity)
    }

    func toHexStringWithAlpha(alpha: CGFloat) -> String {
        let clampedAlpha = max(0.0, min(1.0, alpha)) // Clamp alpha to 0-1
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var currentAlpha: CGFloat = 0

        // Extract RGBA components
        self.getRed(&red, green: &green, blue: &blue, alpha: &currentAlpha)

        let scaledAlpha = Int(clampedAlpha * 255)
        let redInt = Int(red * 255)
        let greenInt = Int(green * 255)
        let blueInt = Int(blue * 255)

        return String(format: "#%02X%02X%02X%02X", scaledAlpha, redInt, greenInt, blueInt)
    }

}
