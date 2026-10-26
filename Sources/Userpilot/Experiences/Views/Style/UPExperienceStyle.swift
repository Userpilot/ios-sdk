//
//  UPExperienceStyle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 26/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves experience fonts and text scaling once, for SwiftUI text and the UIKit text views alike.
//

import SwiftUI

/// One font source for every text surface. Every size scales by the body text style, so authored
/// sizes keep their order. The opt-in flag and the cap act on the SwiftUI size category.
internal enum UPExperienceStyle {
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

extension ContentSizeCategory {
    /// A plain switch keeps iOS 13 free of the iOS 14 `UIContentSizeCategory(_:)` initializer.
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

extension View {
    /// Applied once per SwiftUI root: authored sizes when scaling is off, the capped user size when on.
    func experienceTextSize(scalingEnabled: Bool) -> some View {
        transformEnvironment(\.sizeCategory) { $0 = UPExperienceStyle.textSize($0, scalingEnabled: scalingEnabled) }
    }

    /// Theme family at the resolved size; re-evaluates when the size category changes.
    func experienceFont(_ family: String?, size: CGFloat, bold: Bool = false, italic: Bool = false) -> some View {
        UPExperienceFont(label: self, family: family, size: size, bold: bold, italic: italic)
    }
}

/// A wrapper view rather than a ViewModifier: the SDK's own `Content` and `Environment` types shadow SwiftUI's.
private struct UPExperienceFont<Label: View>: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    let label: Label
    let family: String?
    let size: CGFloat
    let bold: Bool
    let italic: Bool

    var body: some View {
        label.font(Font(UPExperienceStyle.font(
            family: family, size: size, bold: bold, italic: italic, category: sizeCategory)))
    }
}
