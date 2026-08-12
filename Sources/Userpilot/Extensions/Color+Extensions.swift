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

    /// A version of this colour one step "above" the surface it sits on, for a popup or menu that
    /// needs to read as floating rather than painted on.
    ///
    /// Which direction is a step up depends on the surface: a dark card lifts by getting *lighter*,
    /// the way the system's own menus do in dark mode, and a light card lifts by getting slightly
    /// darker, since there is nowhere lighter than white to go. The shift is deliberately small —
    /// enough to separate two surfaces, not enough to read as a different colour.
    ///
    /// - Parameter amount: How far to move, 0...1. The default is tuned to stay subtle on a
    ///   mid-tone brand colour.
    /// - Returns: The adjusted colour, or `self` if the components cannot be read.
    func elevatedAsPopup(by amount: CGFloat = 0.10) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }

        // Toward white on a dark surface, toward black on a light one.
        let target: CGFloat = isLightColor() ? 0 : 1
        let shift = isLightColor() ? amount / 2 : amount
        return UIColor(
            red: red + (target - red) * shift,
            green: green + (target - green) * shift,
            blue: blue + (target - blue) * shift,
            alpha: alpha
        )
    }

    func withOpacity(_ opacity: CGFloat) -> UIColor {
        return self.withAlphaComponent(opacity)
    }

    /// This colour composited over `background`, so a translucent fill can be reasoned about as
    /// the single colour it actually renders as.
    ///
    /// Needed because a theme's tint is applied at low opacity: `primary` at 20% is not what the
    /// eye sees, the blend of it with the card is, and that blend is what has to be checked for
    /// contrast.
    func flattened(over background: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var backRed: CGFloat = 0, backGreen: CGFloat = 0, backBlue: CGFloat = 0, backAlpha: CGFloat = 0
        guard
            getRed(&red, green: &green, blue: &blue, alpha: &alpha),
            background.getRed(&backRed, green: &backGreen, blue: &backBlue, alpha: &backAlpha)
        else { return self }

        return UIColor(
            red: backRed + (red - backRed) * alpha,
            green: backGreen + (green - backGreen) * alpha,
            blue: backBlue + (blue - backBlue) * alpha,
            alpha: 1
        )
    }

    /// WCAG relative luminance, `0` for black and `1` for white.
    ///
    /// The gamma-corrected form rather than the weighted-average one ``isLightColor()`` uses: this
    /// feeds ``upContrastRatio(against:)``, where the shortcut version misjudges saturated
    /// mid-tones badly enough to pass a fill that is not actually distinguishable.
    private var relativeLuminance: CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }

        let linear: (CGFloat) -> CGFloat = { channel in
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The WCAG contrast ratio between this colour and `other`, from `1` (identical) to `21`
    /// (black against white).
    ///
    /// Both colours are assumed opaque — composite a translucent one with
    /// ``flattened(over:)`` first, or the alpha is silently ignored.
    func upContrastRatio(against other: UIColor) -> CGFloat {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
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
