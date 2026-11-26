//
//  TooltipStyle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Keeps tooltip card layout separate from content and engagement state.
//

import UIKit

/// Uses the existing button, colors, dismissContent, general and progress theme fields.
/// Shared components apply those fields themselves; this type owns only the card's layout.
internal struct TooltipStyle {
    let theme: ExperienceTheme

    static let contentInset: CGFloat = 16
    static let sectionSpacing = Constants.Theme.distanceBetweenSections
    static let cornerRadius = Constants.Theme.tooltipCornerRadius
    /// A 44pt hit target with a 24pt close glyph.
    static let closeButtonSize: CGFloat = 44
    static let closeButtonGlyphInset: CGFloat = 10
    static let closeButtonInset = cornerRadius
    static let stepsProgressHeight: CGFloat = 20
    static let stepsProgressBarHeight = Constants.Theme.stepsProgressBarHeight
}
