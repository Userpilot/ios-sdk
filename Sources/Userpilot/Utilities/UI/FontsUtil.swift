//
//  FontsUtil.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  A utility class to load fonts from assets or system font.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
internal extension UIFont {

    /// Resolves a system design, registered bundle font, then a system fallback, in that order.
    /// A nil name returns an unscaled system font; named paths use the existing size-based metrics.
    /// `textStyle` remains accepted for call-site compatibility; scaling is selected by `fontSize`.
    static func matching(
        fontName: String?,
        fontWeight: [UIFontDescriptor.SymbolicTraits],
        fontSize: CGFloat,
        textStyle: UIFont.TextStyle = .body
    ) -> UIFont {
        guard let fontName else { return systemFont(for: fontWeight, size: fontSize) }
        let font = getDefaultSystemFont(fontName: fontName, fontWeight: fontWeight, size: fontSize)
            ?? loadCustomFont(fontName: fontName, fontWeight: fontWeight, fontSize: fontSize)
            ?? systemFont(for: fontWeight, size: fontSize)

        return UIFontMetrics.metricFor(size: fontSize).scaledFont(for: font)
    }

    /// Returns the system font with specified symbolic traits (bold, italic, etc.)
    private static func systemFont(
        for fontWeight: [UIFontDescriptor.SymbolicTraits],
        size: CGFloat
    ) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size)
        return systemFont.fontDescriptor.font(withTraits: fontWeight, size: size) ?? systemFont
    }

    /// Returns the system font with a specific design and traits.
    private static func getDefaultSystemFont(
        fontName: String,
        fontWeight: [UIFontDescriptor.SymbolicTraits],
        size: CGFloat
    ) -> UIFont? {
        guard let design = UIFontDescriptor.SystemDesign(string: fontName) else {
            return nil
        }

        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        descriptor = descriptor.withDesign(design) ?? descriptor

        return descriptor.font(withTraits: fontWeight, size: size) ?? UIFont(descriptor: descriptor, size: size)
    }

    /// Custom fonts require both a matching bundle file and prior registration by the host app.
    /// Lookup does not register fonts or try an unsuffixed family name.
    private static func loadCustomFont(
        fontName: String,
        fontWeight: [UIFontDescriptor.SymbolicTraits],
        fontSize: CGFloat
    ) -> UIFont? {
        let fullFontName = fontName + fontWeight.customFontSuffix

        // Preserve the bundle-file requirement even if UIKit already knows this font name.
        guard (Bundle.main.url(forResource: fullFontName, withExtension: "ttf") ??
               Bundle.main.url(forResource: fullFontName, withExtension: "otf")) != nil else {
            return nil
        }

        if isFontRegistered(fontName: fullFontName) {
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

    /// Legacy registration helper. `matching` intentionally only reads host-registered fonts.
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

private extension UIFontDescriptor {
    /// UIKit may reject a trait combination; callers retain their existing fallback descriptor.
    func font(withTraits traits: [UIFontDescriptor.SymbolicTraits], size: CGFloat) -> UIFont? {
        withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits)).map { UIFont(descriptor: $0, size: size) }
    }
}

private extension Array where Element == UIFontDescriptor.SymbolicTraits {
    /// Keep separate bold/italic entries significant, matching the existing theme-to-traits mapping.
    var customFontSuffix: String {
        if contains(.traitBold) && contains(.traitItalic) { return "-BoldItalic" }
        if contains(.traitBold) { return "-Bold" }
        if contains(.traitItalic) { return "-Italic" }
        return "-Regular"
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

internal extension UIFontMetrics {
    /// Match the existing design-size bands: caption through 15pt, title from 20pt, body between them.
    static func metricFor(size: CGFloat) -> UIFontMetrics {
        if size <= 15 {
            return UIFontMetrics(forTextStyle: .caption1)
        } else if size >= 20 {
            return UIFontMetrics(forTextStyle: .title1)
        } else {
            return UIFontMetrics(forTextStyle: .body)
        }
    }
}
