//
//  Constants.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 06/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// A utility class to load fonts from assets or system font.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
extension UIFont {

    /// Returns a UIFont that matches the specified name, weight, and size.
    /// If the custom font is not available, it falls back to the system font.
    ///
    /// - Parameters:
    ///   - fontName: The name of the custom font. If nil, the system font is used.
    ///   - fontWeight: An array of UIFontDescriptor.SymbolicTraits representing the font's weight.
    ///   - fontSize: The size of the font.
    /// - Returns: A UIFont object matching the specified criteria.
    static func matching(fontName: String?,
                         fontWeight: [UIFontDescriptor.SymbolicTraits],
                         fontSize: CGFloat) -> UIFont {
        guard let fontName = fontName else {
            return UIFont.systemFont(ofSize: fontSize, weight: .regular)
        }

        if let systemFont = getSystemFont(fontName, fontWeight, fontSize) {
            return systemFont
        } else if let customFont = UIFont.loadCustomFont(fontName, fontWeight, fontSize) {
            return customFont
        } else {
            return UIFont.systemFont(ofSize: fontSize, weight: .regular)
        }
    }

    /// Returns the system font based on the provided parameters.
    ///
    /// - Parameters:
    ///   - fontName: The name of the font.
    ///   - fontWeight: An array of UIFontDescriptor.SymbolicTraits representing the font's weight.
    ///   - fontSize: The size of the font.
    /// - Returns: A UIFont object that matches the system font with the specified traits.
    static func getSystemFont(_ fontName: String?,
                              _ fontWeight: [UIFontDescriptor.SymbolicTraits],
                              _ fontSize: CGFloat) -> UIFont? {
        let systemFont = UIFont.systemFont(ofSize: fontSize)
        let design = UIFontDescriptor.SystemDesign(string: fontName) ?? .default

        let fontDescriptor = systemFont.fontDescriptor.withDesign(design)

        // Combine font traits into a single descriptor
        let traits: UIFontDescriptor.SymbolicTraits = fontWeight.reduce(.init(), { $0.union($1) })
        let combinedFontDescriptor = fontDescriptor?.withSymbolicTraits(traits)

        // Create and return a new font with the combined descriptor
        if let combinedFontDescriptor = combinedFontDescriptor {
            return UIFont(descriptor: combinedFontDescriptor, size: fontSize)
        }
        return nil
    }

    /// Checks if a font with the specified name is already registered.
    ///
    /// - Parameter fontName: The name of the font to check.
    /// - Returns: A Boolean value indicating whether the font is registered.
    static func isFontRegistered(fontName: String) -> Bool {
        for family in UIFont.familyNames {
            let fontNames = UIFont.fontNames(forFamilyName: family)
            if fontNames.contains(fontName) {
                return true
            }
        }
        return false
    }

    /// Loads a custom font from the main bundle if it is not already registered.
    ///
    /// - Parameters:
    ///   - fontName: The name of the custom font to load.
    ///   - fontWeight: An array of UIFontDescriptor.SymbolicTraits representing the font's weight.
    ///   - fontSize: The size of the font.
    /// - Returns: A UIFont object if the font was successfully loaded; otherwise, nil.
    static func loadCustomFont(_ fontName: String,
                               _ fontWeight: [UIFontDescriptor.SymbolicTraits],
                               _ fontSize: CGFloat) -> UIFont? {
        // Determine the appropriate font weight suffix
        var customFontWeight = "-Regular"

        if fontWeight.contains(.traitBold) && fontWeight.contains(.traitItalic) {
            customFontWeight = "-BoldItalic"
        } else if fontWeight.contains(.traitItalic) {
            customFontWeight = "-Italic"
        } else if fontWeight.contains(.traitBold) {
            customFontWeight = "-Bold"
        }

        // Check if the font is already registered
        if isFontRegistered(fontName: fontName + customFontWeight) {
            return UIFont(name: fontName + customFontWeight, size: fontSize)
        }

        // Load the font from the bundle
        guard let fontURL = Bundle.main.url(forResource: fontName + customFontWeight, withExtension: "ttf") else {
            print("Failed to find font in bundle.")
            return nil
        }

        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let cgFont = CGFont(fontDataProvider) else {
            print("Failed to load font data.")
            return nil
        }

        // Register the font with Core Text
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(cgFont, &error) {
            print("Error registering font: \(String(describing: error))")
            return nil
        }

        // Return UIFont with the custom font name
        return UIFont(name: cgFont.postScriptName as String? ?? "", size: fontSize)
    }
}

@available(iOS 13.0, *)
extension UIFont.Weight {

    /// Initializes a UIFont.Weight from a string representing a font weight.
    ///
    /// - Parameter string: The string representing the font weight.
    /// - Returns: A UIFont.Weight object if the string matches a known weight; otherwise, nil.
    init?(string: String?) {
        switch string {
        case "Black": self = .black
        case "Heavy": self = .heavy
        case "Bold": self = .bold
        case "Semibold": self = .semibold
        case "Medium": self = .medium
        case "Regular": self = .regular
        case "Light": self = .light
        case "Thin": self = .thin
        case "Ultralight": self = .ultraLight
        default: return nil
        }
    }
}

@available(iOS 13.0, *)
extension UIFontDescriptor.SystemDesign {

    /// Initializes a UIFontDescriptor.SystemDesign from a string representing a design.
    ///
    /// - Parameter string: The string representing the font design.
    /// - Returns: A UIFontDescriptor.SystemDesign object if the string matches a known design; otherwise, nil.
    init?(string: String?) {
        switch string {
        case "Default": self = .default
        case "Monospaced": self = .monospaced
        case "Rounded": self = .rounded
        case "Serif": self = .serif
        default: return nil
        }
    }
}
