//
//  Constants.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 06/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// A utility class to load fonts from assets or system font.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
internal extension UIFont {

    /// Returns a UIFont that matches the specified name, weight, and size, with support for Dynamic Type.
    /// If the custom font is not available, it falls back to the system font.
    ///
    /// - Parameters:
    ///   - fontName: The name of the custom font. If nil, the system font is used.
    ///   - fontWeight: An array of UIFontDescriptor.SymbolicTraits representing the font's traits (e.g., bold, italic).
    ///   - fontSize: The base size of the font.
    ///   - textStyle: The text style for Dynamic Type scaling. Default is `.body`.
    /// - Returns: A UIFont object matching the specified criteria, scaled for Dynamic Type.
    static func matching(fontName: String?,
                         fontWeight: [UIFontDescriptor.SymbolicTraits],
                         fontSize: CGFloat,
                         textStyle: UIFont.TextStyle = .body) -> UIFont {
        guard let fontName else { return systemFont(for: fontWeight, size: fontSize) }
        // Determine the base font
        let font: UIFont = {
            return getDefaultSystemFont(fontName: fontName,
                                        fontWeight: fontWeight,
                                        size: fontSize) ??
                    loadCustomFont(fontName: fontName,
                                  fontWeight: fontWeight,
                                  fontSize: fontSize) ??
                    systemFont(for: fontWeight, size: fontSize)
        }()

        // Apply Dynamic Type scaling
        return UIFontMetrics.metricFor(size: fontSize).scaledFont(for: font)
    }

    /// Returns the system font with specified symbolic traits (bold, italic, etc.)
    private static func systemFont(for fontWeight: [UIFontDescriptor.SymbolicTraits], size: CGFloat) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size)
        let symbolicTraits = UIFontDescriptor.SymbolicTraits(fontWeight)
        if let descriptor = systemFont.fontDescriptor.withSymbolicTraits(symbolicTraits) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return systemFont
    }

    /// Returns the system font with a specific design and traits.
    private static func getDefaultSystemFont(fontName: String,
                                             fontWeight: [UIFontDescriptor.SymbolicTraits],
                                             size: CGFloat) -> UIFont? {
        guard let design = UIFontDescriptor.SystemDesign(string: fontName) else {
            return nil
        }

        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        descriptor = descriptor.withDesign(design) ?? descriptor

        let symbolicTraits = UIFontDescriptor.SymbolicTraits(fontWeight)
        if let finalDescriptor = descriptor.withSymbolicTraits(symbolicTraits) {
            return UIFont(descriptor: finalDescriptor, size: size)
        }

        return UIFont(descriptor: descriptor, size: size)
    }

    /// Loads a custom font from the main bundle if it is not already registered.
    ///
    /// - Parameters:
    ///   - fontName: The name of the custom font to load.
    ///   - fontWeight: An array of UIFontDescriptor.SymbolicTraits representing the font's traits.
    ///   - fontSize: The size of the font.
    /// - Returns: A UIFont object if the font was successfully loaded; otherwise, nil.
    private static func loadCustomFont(fontName: String,
                                       fontWeight: [UIFontDescriptor.SymbolicTraits],
                                       fontSize: CGFloat) -> UIFont? {
        // Determine the appropriate font weight suffix based on traits
        var suffix = "-Regular"
        if fontWeight.contains(.traitBold) && fontWeight.contains(.traitItalic) {
            suffix = "-BoldItalic"
        } else if fontWeight.contains(.traitBold) {
            suffix = "-Bold"
        } else if fontWeight.contains(.traitItalic) {
            suffix = "-Italic"
        }

        let fullFontName = fontName + suffix

        // Check if the font is already registered
        guard (Bundle.main.url(forResource: fullFontName, withExtension: "ttf") ??
               Bundle.main.url(forResource: fullFontName, withExtension: "otf")) != nil else {
            return nil
        }

        if UIFont.familyNames.flatMap({ UIFont.fontNames(forFamilyName: $0) }).contains(fullFontName) {
            return UIFont(name: fullFontName, size: fontSize)
        }
        return nil
    }

    /// Checks if a font with the specified name is already registered.
    private static func isFontRegistered(fontName: String) -> Bool {
        return UIFont.familyNames.contains { family in
            UIFont.fontNames(forFamilyName: family).contains(fontName)
        }
    }

    private static func isCustomFontAvailable(_ fontName: String) -> Bool {
        guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") ??
                Bundle.main.url(forResource: fontName, withExtension: "otf") else {
            print("Font \(fontName) not found!")
            return false
        }

        if UIFont.familyNames.flatMap({ UIFont.fontNames(forFamilyName: $0) }).contains(fontName) {
            return true
        }

        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            return false
        }

        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(font, &error) {
            return true
        } else {
            return false
        }
    }
}

@available(iOS 13.0, *)
internal extension UIFont.Weight {

    /// Initializes a UIFont.Weight from a string representing a font weight.
    ///
    /// - Parameter string: The string representing the font weight.
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
internal extension UIFontDescriptor.SystemDesign {

    /// Initializes a UIFontDescriptor.SystemDesign from a string representing a design.
    ///
    /// - Parameter string: The string representing the font design.
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

extension UIFontMetrics {
    static func metricFor(size: CGFloat) -> UIFontMetrics {
        // using a simple mapping here to try to provide reasonable font scaling
        // behavior based on the original text size in the design
        if size <= 15 {
            return UIFontMetrics(forTextStyle: .caption1)
        } else if size >= 20 {
            return UIFontMetrics(forTextStyle: .title1)
        } else {
            return UIFontMetrics(forTextStyle: .body)
        }
    }
}
