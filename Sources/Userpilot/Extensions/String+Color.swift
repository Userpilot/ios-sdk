//
//  String+Color.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Converts theme color strings using the existing UIKit color and fallback policies.
//

import Foundation
import UIKit

// MARK: - Colors

internal extension String {

    var color: UIColor {
        // Remove any whitespace or `#` prefix
        let cleanedHex = self.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleanedHex.count == 6 || cleanedHex.count == 8 else {
            return .black
        }

        var alpha: CGFloat = 1.0
        var rgbPart = cleanedHex
        if cleanedHex.count == 8 {
            // Extract alpha as the last two characters
            let alphaHex = String(cleanedHex.suffix(2))
            if let alphaValue = Int(alphaHex, radix: 16) {
                alpha = CGFloat(alphaValue) / 255.0
            }
            // Extract RGB as the first 6 characters
            rgbPart = String(cleanedHex.prefix(6))
        }
        // Parse RGB channels
        guard let red = Int(rgbPart.prefix(2), radix: 16),
            let green = Int(rgbPart.dropFirst(2).prefix(2), radix: 16),
            let blue = Int(rgbPart.dropFirst(4).prefix(2), radix: 16)
        else { return  .black }

        return UIColor(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: alpha
        )
    }

    // Function to invert a hex color or return black/white based on luminance
    func invertColor(blackWhite: Bool = true) -> String {
        let colorHex = self.starts(with: "#") ? String(self.dropFirst()) : self

        // Expand shorthand hex (e.g., "03F" to "0033FF")
        if colorHex.count == 3 {
            return "\(colorHex[colorHex.startIndex])\(colorHex[colorHex.startIndex])" +
            "\(colorHex[colorHex.index(colorHex.startIndex, offsetBy: 1)])" +
            "\(colorHex[colorHex.index(colorHex.startIndex, offsetBy: 1)])" +
            "\(colorHex[colorHex.index(colorHex.startIndex, offsetBy: 2)])" +
            "\(colorHex[colorHex.index(colorHex.startIndex, offsetBy: 2)])"
        }

        let redValue = Int(colorHex.prefix(2), radix: 16) ?? 0
        let greenValue = Int(colorHex[colorHex.index(
            colorHex.startIndex,
            offsetBy: 2)..<colorHex.index(colorHex.startIndex, offsetBy: 4)],
            radix: 16) ?? 0
        let blueValue = Int(colorHex.suffix(2), radix: 16) ?? 0

        if blackWhite {
            let luminance = Double(redValue) * 0.299 + Double(greenValue) * 0.587 + Double(blueValue) * 0.114
            return luminance > 186 ? "#000000" : "#FFFFFF"
        } else {
            let invertedR = String(format: "%02X", 255 - redValue)
            let invertedG = String(format: "%02X", 255 - greenValue)
            let invertedB = String(format: "%02X", 255 - blueValue)
            return "#\(invertedR)\(invertedG)\(invertedB)"
        }
    }
}
