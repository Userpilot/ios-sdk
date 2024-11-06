//
//  String+Extension.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 27/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `String+Extension` contains extensions with helper methods for the `String` class.
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

    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var toFontSize: CGFloat {
        if self.contains("px"), let value = Int(self.dropLast(2)) {
            return CGFloat(value)
        } else if let value = Int(self) {
            return CGFloat(value)
        } else {
            return CGFloat(ThemeHandler.DefaultValues.normalTextSize)
        }
    }

    var isRTL: Bool {
        let rtlLanguages = ["ar", "arc", "dv", "fa", "ha", "he", "khw", "ks", "ku", "ps", "ur", "yi", "iw", "ji"]
        return rtlLanguages.contains(self)
    }
}

// MARK: - Colors

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

// MARK: - Json converter

internal extension String {
    /**
    Converts a JSON string into an array of a specified type using `JSONDecoder`.
         
    - Returns: An optional array of the specified type if decoding is successful, or `nil` if decoding fails.
    - Parameter type: The type to decode into, which must conform to `Decodable`.
    */
    func toArray<T: Decodable>() -> [T]? {
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode([T].self, from: Data(self.utf8))
            return decodedData
        } catch {
            // Use a switch statement to handle different types of DecodingError
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type '\(type)' mismatch:")
                    print("  Expected type: \(type)")
                    print("  Contextual info: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath)")
                case .valueNotFound(let value, let context):
                    print("Value '\(value)' not found: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error: \(error)")
                }
            } else {
                print("Failed to decode JSON: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /**
    Converts a JSON string into a specified type using `JSONDecoder`.

    - Returns: An optional instance of the specified type if decoding is successful, or `nil` if decoding fails.
    - Parameter type: The type to decode into, which must conform to `Decodable`.
    */
    func toObject<T: Decodable>() -> T? {
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode(T.self, from: Data(self.utf8))
            return decodedData
        } catch {
            // Use a switch statement to handle different types of DecodingError
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type '\(type)' mismatch:")
                    print("  Expected type: \(type)")
                    print("  Contextual info: \(context.debugDescription)")
                    print("  Coding path: \(context.codingPath)")
                case .valueNotFound(let value, let context):
                    print("Value '\(value)' not found: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error: \(error)")
                }
            } else {
                print("Failed to decode JSON: \(error.localizedDescription)")
            }
            return nil
        }
    }
}
