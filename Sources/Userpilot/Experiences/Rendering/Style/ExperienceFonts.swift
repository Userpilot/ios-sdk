//
//  ExperienceFonts.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Experience fonts and text size: the opt-in scaling, its cap and the theme font lookup.
//

import SwiftUI

/// One font source for every text surface. Every size scales by the body text style, so authored
/// sizes keep their order. The opt-in flag and the cap act on the SwiftUI size category.
internal enum ExperienceFonts {
    /// About twice the authored size (body 17 → 33 pt).
    static let largestTextSize: ContentSizeCategory = .accessibilityLarge

    /// Authored sizes (`.large`) unless the app opted in; then the user's size, capped.
    static func textSize(_ system: ContentSizeCategory, scalingEnabled: Bool) -> ContentSizeCategory {
        // `.large` is the system default, where every size scales by exactly 1.
        guard scalingEnabled else { return .large }
        let all = ContentSizeCategory.allCases
        guard let index = all.firstIndex(of: system), let cap = all.firstIndex(of: largestTextSize) else {
            return system
        }
        // Sizes above the cap are clamped to it.
        return index > cap ? largestTextSize : system
    }

    static func scaledSize(_ size: CGFloat, for category: ContentSizeCategory) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: category.uiContentSizeCategory)
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: size, compatibleWith: traits)
    }

    /// Already scaled: SwiftUI wraps it with `Font(_:)` and UIKit uses it as-is, so nothing scales twice.
    static func font(
        family: String?, size: CGFloat, bold: Bool = false, italic: Bool = false,
        category: ContentSizeCategory
    ) -> UIFont {
        let traits: [UIFontDescriptor.SymbolicTraits] = (bold ? [.traitBold] : []) + (italic ? [.traitItalic] : [])
        return UIFont.lookup(fontName: family, fontWeight: traits, fontSize: scaledSize(size, for: category))
    }
}
