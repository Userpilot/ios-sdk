//
//  File.swift
//  
//
//  Created by Motasem Hamed on 01/10/2024.
//

import Foundation
import UIKit

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

extension UIColor {
    // Function to generate a random color
    static func random() -> UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
