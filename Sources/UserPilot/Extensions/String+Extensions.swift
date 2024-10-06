//
//  String+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 27/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `String+Data` contains extensions with helper methods for the `String` class.
//  These extensions provide additional functionality for checking if strings and optional strings are not empty.
//

import Foundation
import UIKit

internal extension Optional where Wrapped == String {

    var isNotEmpty: Bool {
        return !(self?.isEmpty ?? true)
    }

}

internal extension String {

    var isNotEmpty: Bool {
        return !isEmpty
    }

}

internal extension String {

    var color: UIColor {
        let formattedString = self.hasPrefix("#") ? self : "#\(self)"
        guard let color = UIColor(hexString: formattedString) else {
            return .black
        }
        return color
    }

    func rgbaToColor() -> UIColor {
        guard let regExp = try? NSRegularExpression(
            pattern: #"rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d*(?:\.\d+)?)\s*\)"#,
            options: []
        ) else {
            return UIColor.clear
        }

        let nsRange = NSRange(location: 0, length: self.utf16.count)
        if let match = regExp.firstMatch(in: self, options: [], range: nsRange) {
            // Extract and convert components with meaningful names
            let redValue = Int((self as NSString).substring(with: match.range(at: 1))) ?? 0
            let greenValue = Int((self as NSString).substring(with: match.range(at: 2))) ?? 0
            let blueValue = Int((self as NSString).substring(with: match.range(at: 3))) ?? 0
            let alphaString = (self as NSString).substring(with: match.range(at: 4))
            let alphaValue = CGFloat((alphaString as NSString).floatValue)

            // Ensure values are within the correct range and create the UIColor
            return UIColor(
                red: CGFloat(redValue).clamped(to: 0...255) / 255.0,
                green: CGFloat(greenValue).clamped(to: 0...255) / 255.0,
                blue: CGFloat(blueValue).clamped(to: 0...255) / 255.0,
                alpha: alphaValue.clamped(to: 0.0...1.0)
            )
        }
        return UIColor.clear
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

    // Function to update the opacity of an RGBA or RGB color string
    func updateRgbaOpacity(opacity: String) -> String? {
        // Safely handle the regular expression creation
        guard let regExp = try? NSRegularExpression(pattern: #"\(([^)]+)\)"#, options: []) else {
            return nil
        }

        // Ensure the string starts with "rgba" or "rgb"
        let lowercasedString = self.lowercased()
        guard lowercasedString.starts(with: "rgba") || lowercasedString.starts(with: "rgb") else {
            print("Warning: color passed is not of type rgb/rgba")
            return nil
        }

        // Get the first match for the pattern
        let nsRange = NSRange(location: 0, length: self.utf16.count)
        guard let match = regExp.firstMatch(in: self, options: [], range: nsRange) else {
            return nil
        }

        // Extract the color components inside the parentheses
        var colorComponents = (self as NSString)
            .substring(with: match.range(at: 1))
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if lowercasedString.starts(with: "rgba") {
                // Update the opacity value if it's an "rgba" string
            colorComponents[colorComponents.count - 1] = opacity
        } else if lowercasedString.starts(with: "rgb") {
            // Append the opacity value if it's an "rgb" string
            colorComponents.append(opacity)
        }

        // Return the updated "rgba(...)" string
        return "rgba(\(colorComponents.joined(separator: ", ")))"
    }

    // Function to convert a hex color string to an RGB string
    func hexToRgb() -> String {
        let cleanHex = self.replacingOccurrences(of: "#", with: "")
        let redValue = Int(cleanHex.prefix(2), radix: 16) ?? 0
        let greenValue = Int(cleanHex[cleanHex
            .index(cleanHex.startIndex, offsetBy: 2)..<cleanHex.index(cleanHex.startIndex, offsetBy: 4)],
            radix: 16) ?? 0
        let blueValue = Int(cleanHex.suffix(2), radix: 16) ?? 0
        return "rgb(\(redValue), \(greenValue), \(blueValue))"
    }
}
